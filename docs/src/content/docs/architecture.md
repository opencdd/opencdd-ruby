---
title: Architecture
description: How opencdd is structured internally, the principles followed, and the extension points for common features.
---

This document explains how `opencdd` is structured internally, what
the extension points are, and where to look when adding common kinds
of features. Start here when contributing.

## Design principles

Five principles, all enforced by `spec/code_quality_spec.rb` or by
convention:

### 1. Open/Closed (OCP)

Adding a new flavor of thing = adding a new file/class, not editing a
switch statement.

**Examples**:
- New entity type → new `Opencdd::Entity` subclass + entry in
  `MetaClasses#built_in_registry`. No switch in `Database` to update.
- New validator rule → new `Opencdd::Validator::*Rule` subclass + entry
  in `Runner::RULES`.
- New exporter → new `Opencdd::Exporters::*` class + autoload.
- New Parcel reader → new `Opencdd::Parcel::*Reader` class + entry in
  `Opencdd::Reader::DETECTORS`.

### 2. DRY — single source of truth

| Concern | SSOT file |
|---------|-----------|
| Property IDs (`MDC_P###`) | `lib/opencdd/property_ids.rb` — `REGISTRY` |
| Meta-class definitions | `lib/opencdd/meta_class.rb` — `MetaClasses` registry |
| Parcel sheet-type strings | `Opencdd::MetaClass::PARCEL_SHEET_TYPES` |
| Parcel column variant mapping | `Opencdd::Parcel::SheetSchema::VARIANT_TO_CANONICAL` |
| Collection wire-form parsing | `Opencdd::StructuredValues.unwrap_and_split` |
| Directory layout detection | `Opencdd::Parcel::LayoutDetector` |
| IRDI grammar | `lib/opencdd/irdi.rb` |
| Validator rule list | `Opencdd::Validator::Runner::RULES` |
| YAML model attributes | `lib/opencdd/model/yaml_entity.rb` |

`bin/lint-no-raw-mdc` enforces that no `MDC_P###` / `MDC_C###` / etc.
literal appears outside the designated SSOT files. Run via
`rake lint:registry`.

### 3. MECE — each concern in exactly one place

- The **model** (`Opencdd::Entity`, `Klass`, `Property`, ...) doesn't
  know about formats. It has typed accessors over its `properties` hash.
- The **YAML model** (`Opencdd::Model::YamlEntity`,
  `Opencdd::Model::YamlDatabase`) provides CDD-native typed attributes
  backed by `Lutaml::Model::Serializable`. YAML is the canonical
  persistence format.
- The **format readers/writers** (Parcel, CDDAL, exporters) don't
  know about validation or powertype semantics. They produce/consume
  the model.
- The **validator** doesn't know about formats. It walks entities.
- The **Database** is the boundary between formats and the model: it
  owns entity identity and graph invariants.

### 4. Encapsulation

- No `.send` to private methods (enforced by `spec/code_quality_spec.rb`).
  The field DSL uses `instance_exec(&block)` for synthetic fields.
- No `instance_variable_set` / `instance_variable_get` across objects.
- Entity state is mutated only through named mutators
  (`attach_parent_irdi`, `add_child`, `declare_property`,
  `attach_version_history`, `attach_source_location`,
  `write_property!`).

### 5. `autoload`, not `require_relative`

Internal library code uses Ruby `autoload`. The autoload entry is
declared in the **immediate parent namespace's file**.

`spec/code_quality_spec.rb` enforces both:
```ruby
it "does not use require_relative" do ... end
it "does not use require for internal cdd paths" do ... end
```

## Layered architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│ Format adapters                                                      │
│                                                                      │
│  Opencdd::Parcel::*Reader  ─┐                                        │
│  Opencdd::Parcel::Writer   ─┤                                        │
│  Opencdd::Cddal::Lexer      │                                        │
│  Opencdd::Cddal::Parser     ├──────► Opencdd::Database ◄────────┐    │
│  Opencdd::Cddal::Builder    │                  │                 │    │
│  Opencdd::Cddal::Serializer ─┘                  │                 │    │
│  Opencdd::Cddal::Resolver / Fetcher             │                 │    │
│  Opencdd::Exporters::*       │                  ▼                 │    │
│                                ┌─────────────────────────┐       │    │
│  Opencdd::Model::YamlDatabase │ Entity layer            │       │    │
│  Opencdd::Model::YamlEntity   │  Opencdd::Entity        │       │    │
│  (Lutaml::Model::Serializable)│  Opencdd::Klass         │       │    │
│                                │  Opencdd::Property      │       │    │
│                                │  Opencdd::Unit          │       │    │
│                                │  Opencdd::ValueList     │       │    │
│                                │  Opencdd::ValueTerm     │       │    │
│                                │  Opencdd::Relation      │       │    │
│                                │  Opencdd::ViewControl   │       │    │
│                                └─────────────────────────┘       │    │
│                                          │                       │    │
│                                          ▼                       │    │
│                                ┌─────────────────────────┐       │    │
│                                │ Registry layer          │       │    │
│                                │  Opencdd::MetaClasses   │ ──────┘    │
│                                │  Opencdd::PropertyIds   │            │
│                                │  Opencdd::AliasTable    │            │
│                                │  Opencdd::IRDI          │            │
│                                └─────────────────────────┘            │
│                                                                       │
│  Opencdd::Validator::* ──── walks entities via Database ──────────► │
│  Opencdd::Parcel::LayoutDetector ─── shared detection ──────────────│
│  Opencdd::Parcel::EntityManifest ─── _entity.json parsing ──────────│
│  Opencdd::Cddal::ValueSerializer ─── AST→wire-form ────────────────│
│  Opencdd::StructuredValues ─── collection parsing SSOT ────────────│
└──────────────────────────────────────────────────────────────────────┘
```

## The model layer

### `Opencdd::Entity` — base class

Every CDD object is an `Entity`. Key state:

```ruby
attr_reader :irdi, :properties, :schema, :meta_class_irdi, :source_location
```

- `irdi` — canonical identity.
- `properties` — the raw `Hash<String,String>` from any source. Lossless.
- `meta_class_irdi` — points to the M2 meta-class that defines this entity's shape.
- `source_location` — file:line where this entity was declared (CDDAL
  imports) or nil (Parcel readers).

### The field DSL

Typed accessors are declared via the `field` DSL, evaluated lazily via
`instance_exec` (no `send` to private methods):

```ruby
class Opencdd::Property < Opencdd::Entity
  # Direct read from properties hash with type coercion
  field :value_format, "MDC_P024", :string

  # Multilingual — picks up from REGISTRY automatically
  field :definition, "MDC_P006"

  # Synthetic — block-form (no send-to-private)
  field(:parsed_data_type) do
    Opencdd::DataType.parse_or_string(properties[Opencdd::PropertyIds::MDC_P022])
  end
end
```

The DSL stores declarations in `Opencdd::Entity::FieldRegistry`. The
`FieldReader` service dispatches reads:

```ruby
prop.value_format        # calls FieldReader.read(prop, :value_format)
prop.parsed_data_type    # evaluates the synthetic block via instance_exec
```

### Entity field-access seam

```ruby
entity.read_field(:preferred_name, lang: :fr)   # → typed read via FieldRegistry
entity.write_property!("MDC_P066", guid)        # → write via canonical-id resolution
```

### `Opencdd::Klass` — the powertype-aware class entity

`Klass` extends `Entity` with class-graph state and the powertype API:

```ruby
attr_reader :parent_irdi, :children, :declared_property_irdis, :database

# Mutators (called by Database during finalize!)
def attach_parent_irdi(irdi)
def add_child(klass)
def declare_property(irdi)
def attach_database(database)

# Powertype API (4-layer ontology)
def powertype?                              # class_type == CATEGORICAL_CLASS
def categorical_instances(database = @database)
def sub_powertypes(database = @database)
def powertype_owners(database = @database)
```

## The YAML model layer

`Opencdd::Model::YamlEntity` and `Opencdd::Model::YamlDatabase` extend
`Lutaml::Model::Serializable`. They provide CDD-native typed attributes
with semantic names (not wire-format keys):

```yaml
---
irdi: AAA001
type: class
code: AAA001
preferred_name:
  en: Vehicle
  fr: Véhicule
class_type: ITEM_CLASS
superclass: UNIVERSE
applicable_properties:
- AAAP001
- AAAP002
```

Conversion between the YAML model and the existing Entity model is via
adapter methods:

```ruby
# Entity → YAML
yaml_entity = Opencdd::Model::YamlEntity.from_entity(entity)
yaml = yaml_entity.to_yaml

# YAML → Database
db = Opencdd::Database.from_yaml(yaml_string)

# Database → YAML
yaml = db.to_yaml
```

The YAML layer is the canonical persistence format. CDDAL and Parcel
are format adapters on top.

## The registry layer

### `Opencdd::MetaClasses` — M2

The fixed set of IEC 61360 meta-classes. Each `MetaClass` instance carries:

- `irdi` — `"MDC_C002"`
- `name` — `"Class"`
- `entity_class` — the Ruby class (`Opencdd::Klass`)
- `type` — the Symbol used throughout the codebase (`:class`)
- `sheet_type` — the Parcel sheet-type string (`"CLASS"`)
- `allowed_property_ids` — which `MDC_P###` IDs may appear on this meta-class

Accessors:
- `MetaClasses.for(irdi)` → `MetaClass` or nil
- `MetaClasses.entity_class_for_type(:class)` → `Opencdd::Klass`
- `MetaClasses.sheet_type_for_type(:class)` → `"CLASS"`
- `MetaClasses.type_for("MDC_C002")` → `:class`
- `MetaClasses.meta_class_for_type(:class)` → `"MDC_C002"`
- `MetaClasses.code_property_id_for("MDC_C002")` → `"MDC_P001_5"`

This is the single source of truth. Database, Writer, WorkbookReader,
and codegen all consult MetaClasses instead of maintaining parallel
maps.

### `Opencdd::PropertyIds` — MDC_P### SSOT

`REGISTRY` is a `Hash<String, Entry>` keyed by property ID. `Entry`
has `aliases`, `applies_to`, `multilingual`, `value_kind`.

For every key in `REGISTRY`, a matching constant is defined:

```ruby
Opencdd::PropertyIds::MDC_P022  # => "MDC_P022"
```

So callers write `Opencdd::PropertyIds::MDC_P022`, never the raw
string. `bin/lint-no-raw-mdc` enforces this.

## The Database layer

`Opencdd::Database` is the in-memory store. It owns:

- **Entity identity**: `find`, `find_by_code`, `find_by_name`
- **Type-partitioned accessors**: `classes`, `properties`, `units`, ...
- **Indexes**: rebuilt on `finalize!` (idempotent)
- **Mutations**: `add_entity`, `merge`, `rename_entity`,
  `apply_change_request`, `drop_dictionary`
- **Graph walkers**: `effective_properties_of`, `composition_tree`,
  `relations_for`, `instances_of`, `valid_class_reference?`
- **Semantic equality**: `semantically_equal?` (used by every round-trip spec)
- **Coercion helpers**: `coerce_entity(value)`, `coerce_irdi(value)`
- **YAML persistence**: `to_yaml` / `self.from_yaml`

### The `finalize!` invariant

After entities are added (from any source), `finalize!` rebuilds reverse
indexes and links the entity graph:

```ruby
def finalize!
  normalize_reference_collections!   # via each_reference_collection
  link_class_hierarchy!              # parent/child via MDC_P010
  link_property_classes!             # declared_property_irdis via two strategies:
                                     #   1. Relation entities (Parcel)
                                     #   2. MDC_P021 definition_class (CDDAL)
  link_value_lists!                  # enum property → value list
  rebuild_symbol_table!
  self
end
```

Idempotent — guarded by `@finalized` flag (re-runs are no-ops unless
entities changed). All format readers call `finalize!` before returning.

## Shared infrastructure

| Module | Purpose |
|--------|---------|
| `StructuredValues` | SSOT for `{a,b,c}` / `(a,b)` wire-form parsing |
| `ParseHelpers` | Legacy back-compat layer; delegates to StructuredValues |
| `Parcel::LayoutDetector` | Directory layout detection (sharded/flat/legacy) |
| `Parcel::EntityManifest` | `_entity.json` sidecar parsing + stub entities |
| `Cddal::ValueSerializer` | AST node → wire-string conversion |
| `Cddal::Resolver` / `Fetcher` | Module import path/URL resolution |

## Extension points

### Adding a new entity type

1. Subclass `Opencdd::Entity` in `lib/opencdd/<name>.rb`.
2. Register in `Opencdd::MetaClasses#built_in_registry`.
3. Add fields via the `field` DSL.
4. Add an autoload entry in `lib/opencdd.rb`.
5. Write specs.

### Adding a new validator rule

1. Subclass `Opencdd::Validator::Rule` in
   `lib/opencdd/validator/<name>_rule.rb`.
2. Override `id`, `applies?`, `value_passes?`, `message`.
3. Add to `Opencdd::Validator::Runner::RULES`.
4. Add autoload to `lib/opencdd/validator.rb`.

### Adding a YAML attribute

1. Add `attribute :name, :type` to `YamlEntity`.
2. Add extraction in `YamlEntity.from_entity`.
3. Add reconstruction in `YamlEntity#to_entity`.
4. Spec the round-trip.

## Code quality enforcement

`spec/code_quality_spec.rb` runs on every CI build and forbids:

- `.send(` — use `public_send` or `instance_exec(&block)`
- `instance_variable_set` / `instance_variable_get`
- `respond_to?` for type checks
- `require_relative` in `lib/`
- `require "cdd/..."` / `require "opencdd/..."` in `lib/`

The `lib/opencdd/cddal/generated_parser.rb` file is exempt (machine-generated).
