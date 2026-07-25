---
title: YAML persistence (lutaml-model)
description: The canonical on-disk persistence format for CDD content, using CDD-native attribute names via Lutaml::Model.
published: 2026-07-25
section: Guides
order: 40
---

YAML is the canonical persistence format for CDD content in opencdd.
It uses `Lutaml::Model::Serializable` for framework-provided
serialization — no hand-rolled `to_yaml` on any model class.

## Why YAML?

- **Diff-friendly** — line-oriented, meaningful diffs in version control.
- **Human-readable** — no specialized tooling required.
- **Semantic** — uses CDD-native attribute names (`preferred_name`,
  `superclass`, `class_type`), not wire-format keys (`MDC_P004`,
  `MDC_P010`, `MDC_P011`).
- **Framework-serialized** — `Lutaml::Model` handles all the
  serialization; the model classes declare typed attributes only.

## YAML shape

```yaml
---
source_language: en
translation_languages:
- fr
- ja
entities:
- irdi: AAA001
  type: class
  code: AAA001
  preferred_name:
    en: Vehicle
    fr: Véhicule
    ja: 車両
  definition:
    en: device that transports people or goods
  class_type: ITEM_CLASS
  superclass: UNIVERSE
  applicable_properties:
  - AAAP001
  - AAAP002
- irdi: AAAP001
  type: property
  code: AAAP001
  preferred_name:
    en: vehicle length
  data_type: REAL_TYPE
  definition_class: AAA001
  unit: metre
  property_data_element_type: NON_DEPENDENT_P_DET
```

Every entity uses semantic CDD names. Multilingual fields are nested
Hash (`{lang: text}`). Collection fields are Arrays. No `MDC_P###`
keys appear in the YAML.

## API

```ruby
# Serialize a Database to YAML
yaml = db.to_yaml
File.write("dictionary.yaml", yaml)

# Load from YAML
db = Opencdd::Database.from_yaml(File.read("dictionary.yaml"))

# Single entity
yaml_entity = Opencdd::Model::YamlEntity.from_entity(entity)
puts yaml_entity.to_yaml

parsed = Opencdd::Model::YamlEntity.from_yaml(yaml_string)
entity = parsed.to_entity(database)
```

## The adapter pattern

The YAML model (`Opencdd::Model::YamlEntity`,
`Opencdd::Model::YamlDatabase`) is a separate layer from the
in-memory model (`Opencdd::Entity`, `Opencdd::Database`). Conversion
methods bridge between them:

```
Opencdd::Database
       │
       ▼ .to_yaml
Opencdd::Model::YamlDatabase
       │
       ▼ .to_yaml (Lutaml::Model)
YAML string

YAML string
       │
       ▼ .from_yaml (Lutaml::Model)
Opencdd::Model::YamlDatabase
       │
       ▼ .to_database
Opencdd::Database
```

This separation means:
- The in-memory model can evolve independently
- CDDAL and Parcel formats work unchanged
- Adding JSON output is trivial (lutaml-model provides it)
- All 825+ existing specs continue to pass

## Typed attributes

`Opencdd::Model::YamlEntity` declares its attributes via
`Lutaml::Model::Serializable`:

```ruby
class YamlEntity < Lutaml::Model::Serializable
  attribute :irdi, :string
  attribute :type, :string
  attribute :code, :string
  attribute :preferred_name, :hash      # multilingual: {lang => text}
  attribute :class_type, :string
  attribute :superclass, :string
  attribute :applicable_properties, :string, collection: true
  attribute :data_type, :string
  # ... ~25 total attributes
end
```

Each attribute maps directly to a CDD concept:
- `preferred_name` → the entity's human-readable name (per language)
- `class_type` → ITEM_CLASS, CATEGORICAL_CLASS, etc.
- `superclass` → the parent class in the hierarchy
- `applicable_properties` → the set of properties declared on this class
- `data_type` → the value type for a Property

## Round-trip guarantees

```ruby
db = Opencdd::Cddal.parse_file("oceanrunner.cddal")
yaml = db.to_yaml
db2 = Opencdd::Database.from_yaml(yaml)

db.entities.size == db2.entities.size         # true
db.classes.size   == db2.classes.size         # true
db.properties.size == db2.properties.size     # true
db2.find_by_code("AAA200").powertype?         # true
```

The YAML round-trip preserves entity count, types, multilingual
fields, powertype semantics, and superclass relationships.
