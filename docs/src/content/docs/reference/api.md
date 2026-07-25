---
title: API reference
description: Key classes and methods exposed by the opencdd gem.
published: 2026-07-25
section: Reference
order: 100
---

This page lists the most-used classes and methods. For full details,
read the source — every public method has a docstring and a spec.

## `Opencdd::Database` — the in-memory store

```ruby
db = Opencdd::Database.new
db.add_entity(entity)
db.finalize!                     # idempotent — rebuilds reverse indexes
```

### Lookup

| Method | Returns |
|--------|---------|
| `find(irdi)` | `Entity` or nil |
| `find_by_code(code)` | `Entity` or nil |
| `find_all_by_code(code)` | `Array<Entity>` |
| `find_by_name(name, type:, lang:)` | `Entity` or nil |
| `resolve_reference(ref)` | `Entity` or nil — accepts Entity/IRDI/String |
| `coerce_entity(value)` | `Entity` or nil |
| `coerce_irdi(value)` | `IRDI` or nil |

### Type-partitioned accessors

```ruby
db.classes        # Array<Klass>
db.properties     # Array<Property>
db.units          # Array<Unit>
db.value_lists    # Array<ValueList>
db.value_terms    # Array<ValueTerm>
db.relations      # Array<Relation>
db.view_controls  # Array<ViewControl>
db.entities       # Array<Entity> — everything flat
```

### Graph queries

| Method | Returns |
|--------|---------|
| `root_classes` | classes with no parent |
| `children_of(klass)` | direct subclasses |
| `subclasses_of(klass)` | recursive descendants |
| `properties_of(klass)` | declared properties |
| `effective_properties_of(klass)` | inherited + declared + is_case_of closure |
| `value_list_of(property)` | linked ValueList |
| `relations_for(domain:, codomain:)` | filtered Array<Relation> |
| `classes_with_property(property)` | classes declaring this property |

### Powertype API (4-layer ontology)

| Method | Returns |
|--------|---------|
| `categorical_classes` | all `CATEGORICAL_CLASS` instances |
| `instances_of(categorical_klass)` | powertype instances of the given class |
| `valid_class_reference?(categorical_klass, value)` | predicate for CLASS_REFERENCE validation |

### Mutation

```ruby
db.add_entity(entity)                # idempotent on IRDI
db.merge(other_db)                   # union, other wins on conflict
db.rename_entity(old_code, new_code) # rewrites every back-reference
db.remove_by_irdi(irdi)              # remove + clean back-refs
db.drop_dictionary(parcel_id)        # remove all entities from a parcel
db.apply_change_request(cr, removals: [])  # transactional upsert
```

### Loading

```ruby
Opencdd::Database.load(path)             # auto-detects format
Opencdd::Database.load_workbook(path)    # .xlsx
Opencdd::Database.load_flat_dir(path)    # legacy .xls dir
Opencdd::Database.load_sharded_dir(path) # per-class sharded
```

## `Opencdd::Entity` and subclasses

The base class for all CDD entities. Seven typed subclasses:

| Subclass | Meta-class | Represents |
|----------|------------|------------|
| `Opencdd::Klass` | `MDC_C002` | A class |
| `Opencdd::Property` | `MDC_C003` | A property definition |
| `Opencdd::Unit` | `MDC_C009` | A unit of measurement |
| `Opencdd::ValueList` | `MDC_C005` | An enumeration / value list |
| `Opencdd::ValueTerm` | `MDC_C010` | A term in a value list |
| `Opencdd::Relation` | `MDC_C011` | A typed relation / function |
| `Opencdd::ViewControl` | `EXT_C001` | A view definition |

### Field DSL

Typed accessors are declared via the `field` DSL. Adding a field is
one line — no edits to the exporter, validator, or TS codegen:

```ruby
class Opencdd::Property < Opencdd::Entity
  field :value_format, "MDC_P024", :string

  # Multilingual — picks up from REGISTRY
  field :definition, "MDC_P006"

  # Synthetic — block-form (no send-to-private)
  field(:parsed_data_type) do
    Opencdd::DataType.parse_or_string(properties[Opencdd::PropertyIds::MDC_P022])
  end
end
```

### `Klass` powertype API

```ruby
klass.powertype?                          # true if CATEGORICAL_CLASS
klass.categorical_instances(database)     # subclasses that are its options
klass.powertype_owners(database)          # ancestor categorical classes
klass.ancestors                           # superclass chain
klass.descendants                         # recursive subclasses
klass.effective_properties                # via Opencdd::EffectiveProperties
```

## `Opencdd::MetaClasses` — M2 layer

The fixed set of IEC 61360 meta-classes.

```ruby
Opencdd::MetaClasses.for("MDC_C002")              # => #<MetaClass Class>
Opencdd::MetaClasses.entity_class_for_type(:class) # => Opencdd::Klass
Opencdd::MetaClasses.sheet_type_for_type(:class)  # => "CLASS"
Opencdd::MetaClasses.type_for("MDC_C002")         # => :class
Opencdd::MetaClasses.meta_class_for_type(:class)  # => "MDC_C002"
Opencdd::MetaClasses.code_property_id_for("MDC_C002")  # => "MDC_P001_5"
Opencdd::MetaClasses.all                          # => Array<MetaClass>
```

Single source of truth for type/sheet/Ruby-class mappings.

## `Opencdd::PropertyIds` — property ID registry

```ruby
Opencdd::PropertyIds::REGISTRY.size            # ~120 IDs
Opencdd::PropertyIds::MDC_P022                  # => "MDC_P022"
Opencdd::PropertyIds.entry("MDC_P022")         # => Entry(aliases: [:data_type], ...)
Opencdd::PropertyIds.multilingual?("MDC_P004") # => true
Opencdd::PropertyIds.canonical_id("data_type") # => "MDC_P022"
Opencdd::PropertyIds.normalize("MDC_P004.en")  # => "MDC_P004.en"
```

No raw `"MDC_P###"` literal outside this file — `bin/lint-no-raw-mdc`
enforces this.

## `Opencdd::IRDI` — identifier parsing

```ruby
Opencdd::IRDI.parse("0112/2///62656_1#AAA001##1")  # => #<IRDI>
Opencdd::IRDI.parse("AAA001")                       # => #<IRDI> short form
irdi.full_form                                      # => "0112/2///62656_1#AAA001##1"
irdi.short_form                                     # => "AAA001"
irdi.code                                           # => "AAA001"
irdi.supplier                                       # => "0112/2///62656_1"
irdi.version                                        # => 1
irdi.comment                                        # => nil
```

## `Opencdd::Cddal` — plain-text format

```ruby
Opencdd::Cddal.parse(source)                  # → Database
Opencdd::Cddal.parse_file(path)               # → Database
Opencdd::Cddal.parse(source,
                      resolver: resolver,
                      fetcher: fetcher,
                      source_file: "main.cddal")

Opencdd::Cddal.serialize(database)            # → String
Opencdd::Cddal.serialize_to_file(database, path)
```

### Module system

```ruby
Opencdd::Cddal::Resolver.new(base_path:, search_path:, fetcher:, strict:, quiet:)
Opencdd::Cddal::Fetcher::NetHttp.new(cache_dir:, offline:)  # default
Opencdd::Cddal::Fetcher::InMemory.new(url_map)              # for tests
```

## `Opencdd::Parcel` — Excel format

### Readers

```ruby
Opencdd::Parcel::WorkbookReader.new(path).load_into(db)    # .xlsx
Opencdd::Parcel::FlatDirReader.new(dir).load_into(db)      # 6-file .xls
Opencdd::Parcel::ShardedDirReader.new(dir).load_into(db)   # per-class sharded
Opencdd::Parcel::CsvReader.new(path).load_into(db)         # CSV / TXT
```

### Writer

```ruby
Opencdd::Parcel::Writer.new(db).write(
  path_or_io,
  parcel_id: "MY_DICT",
  project_id: "MY_PROJECT",
  source_language: "en",
  translation_languages: %w[fr ja],
)
```

### Split / aggregate

```ruby
Opencdd::Parcel.aggregate(*paths)                    # → Database
Opencdd::Parcel.split(db, by: :entity_type)          # → Hash{Symbol => Database}
Opencdd::Parcel.split(db, by: :root_class)
Opencdd::Parcel.split(db, by: :each_class)
Opencdd::Parcel.split(db, by: ->(entity) { ... })    # custom partitioner
Opencdd::Parcel::Selector.new(db)                    # entity selection w/ class closure
```

## `Opencdd::Validator`

```ruby
errors = Opencdd::Validator.run(database)
# → Array<ValidationError>

# Reusable predicates
Opencdd::Validator.irdi_well_formed?(value)
Opencdd::Validator.mandatory_present?(value)
Opencdd::Validator.pattern_valid?(value, pattern)
Opencdd::Validator.class_hierarchy_acyclic?(database)
```

See [Validator rules](/reference/validator-rules/) for the rule catalogue.

## `Opencdd::Exporters`

```ruby
Opencdd::Exporters::Json.new.to_json(db, pretty: true)   # → String
Opencdd::Exporters::Yaml.new.to_yaml(db)                 # → String
Opencdd::Exporters::Mermaid.new.to_diagram(db)           # → String (Mermaid markdown)
```

All exporters share a common `Opencdd::Exporters.entity_payload(entity, database:)`
helper for the per-entity wire shape.

## Exceptions

| Class | When raised |
|-------|-------------|
| `Opencdd::IRDI::ParseError` | Unparseable IRDI string |
| `Opencdd::Cddal::LexError` | CDDAL lexer cannot tokenize |
| `Opencdd::Cddal::ParseError` | CDDAL parser syntax error |
| `Opencdd::Cddal::ResolutionError` | Unresolved symbolic reference (strict mode) |
| `Opencdd::Cddal::ImportError` | Module/import failure or cycle |
