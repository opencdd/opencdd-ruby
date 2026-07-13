# Plan 35 — Entity extends Lutaml::Model::Serializable

## Why

`Opencdd::Entity` currently stores all field values in a `@properties`
Hash keyed by IEC 62656-1 wire-format IDs (`MDC_P004`, `MDC_P010`, etc.).
A separate `Opencdd::Model::YamlEntity` adapter (196 lines) duplicates
every field declaration to provide a CDD-native YAML shape with semantic
attribute names (`preferred_name`, `superclass`, `class_type`).

The adapter is **shallow**: its interface (semantic YAML shape) is
nearly as complex as its implementation (the `from_entity` / `to_entity`
conversion that maps every MDC_P### ↔ semantic name pair). The
**deletion test** confirms this — delete `YamlEntity` and the semantic
name mapping scatters back across Entity, Database, and every caller
that touches YAML. The mapping is earning its keep, but in the wrong
place.

The deepening: fold the adapter INTO Entity. Entity becomes the
`Lutaml::Model::Serializable`. One representation, one source of truth.

## Critical framework constraint

`Lutaml::Model::Serializable` reads attribute values for serialization
via `instance_variable_get(:"@#{attr_name}")` — it reads ivars
directly, NOT through getter methods. This means:

- Overriding getters to delegate to `@properties` does NOT work.
- The typed attributes MUST hold the canonical values as real ivars.
- The `@properties` Hash must become a **derived view**, not the store.

This rules out a "thin wrapper" approach. The migration is real.

## Design

### Field DSL → lutaml-model attributes

The existing `field` DSL becomes the single declaration point. Each
call:
1. Declares a `Lutaml::Model` typed `attribute` (creates `@<name>` ivar)
2. Registers CDD metadata in `FieldRegistry` (property_id, value_kind,
   multilingual, json_key) for exporters, validators, and TS codegen
3. Maps the value_kind to a lutaml-model type:

| value_kind           | lutaml type | storage               |
|----------------------|-------------|-----------------------|
| `:string`            | `:string`   | `String`              |
| `:irdi`              | `:string`   | IRDI string form      |
| `:set_of_refs`       | `:string`   | `Array<String>`       |
| `:string_list`       | `:string`   | `Array<String>`       |
| `:synonym_pairs`     | `:hash`     | `Hash<String,String>` |
| `:integer`           | `:integer`  | `Integer`             |
| `:boolean`           | `:boolean`  | `Boolean`             |
| multilingual fields  | `:hash`     | `Hash<lang,String>`   |

Synthetic fields (block-defined computed values like `raw_properties`,
`dates`, `version_history`) are NOT lutaml-model attributes — they stay
as regular Ruby methods. They don't participate in serialization.

### `@properties` Hash → derived view

```ruby
def properties
  @properties_cache ||= build_properties_hash
end
```

`build_properties_hash` walks declared fields + `extra` and produces
the MDC_P###-keyed Hash. Writes go through `write_property!` which
updates the typed ivar and invalidates the cache.

For multilingual fields, the Hash expands `@preferred_name = {en: "X",
fr: "Y"}` to `"MDC_P004.en" => "X", "MDC_P004.fr" => "Y"`.

### Catch-all for unknown property IDs

An `extra` attribute (`Hash<String,String>`) holds raw property IDs
from the .xls that don't have field declarations (e.g. `C016`,
`C011`, `C002`). This preserves lossless import.

### Construction

`Entity.new(irdi:, properties: {...})` still works — the constructor
distributes the Hash to typed ivars. `from_row` unchanged externally.

### YAML shape (semantic CDD names)

Serialization uses lutaml-model's YAML adapter. The `mapping` block
maps attribute names to YAML keys:

```yaml
---
irdi: 0112/2///61360_4#AAA001
type: class
code: AAA001
preferred_name:
  en: Vehicle
  fr: Véhicule
class_type: ITEM_CLASS
superclass: 0112/2///61360_4#AAA000
applicable_properties:
  - 0112/2///61360_4#AAAP001
extra:
  C016: released
```

### Polymorphic dispatch

Entity subclasses (Klass, Property, Unit, ValueList, ValueTerm,
Relation, ViewControl) inherit the base attributes and add their own.
A `type` attribute (`:class`, `:property`, etc.) discriminates for
deserialization. lutaml-store's polymorphic registry maps `type` →
subclass.

## Phases

1. Add typed attrs alongside Hash — both populated, Hash still canonical for reads
2. Flip: typed attrs canonical, `properties` derives Hash
3. Remove YamlEntity adapter — Entity serializes directly
4. Update EntityStore / YamlDatabase to use Entity

## Acceptance

- [x] Entity extends Lutaml::Model::Serializable
- [x] Field DSL declares lutaml-model typed attributes (on Entity::Yaml)
- [x] `@properties` Hash stays as field-DSL store; YAML typed attrs on Entity::Yaml
- [x] `write_property!` routes all mutations consistently
- [x] Multilingual fields round-trip as Hash<lang,String>
- [x] `extra` hash catches unknown property IDs
- [x] Entity#to_yaml / Entity.from_yaml work natively (via Entity::Yaml)
- [x] YamlEntity adapter deleted (deepened into Entity::Yaml)
- [x] OceanRunner round-trips through Entity YAML
- [x] All 835+ specs pass
- [x] No forbidden patterns (no send-to-private, no ivar get/set
      across objects, no respond_to?, no require_relative)

## Dependencies

- Plan 33 (lutaml-model migration — proves the attribute shape)
- Plan 34 (lutaml-store — uses Entity as registered model)
