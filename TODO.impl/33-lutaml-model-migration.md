# Plan 33 — lutaml-model migration with CDD-native YAML model

## Why

User decision: migrate to lutaml-model with YAML as the canonical
persistence format. The model must be "fully native to CDD ontology"
— using CDD semantic names (preferred_name, superclass, class_type)
not wire-format keys (MDC_P004, MDC_P010, MDC_P011).

## Approach

Adapter pattern: create `Opencdd::Model::YamlEntity` and
`Opencdd::Model::YamlDatabase` extending `Lutaml::Model::Serializable`
with typed attributes and CDD-native names. Conversion methods bridge
between the YAML model and the existing Entity model. No changes to
existing Entity/readers/writers — 813 specs stay green.

### YAML shape

```yaml
---
irdi: 0112/2///61360_4#AAA001
type: class
code: AAA001
preferred_name:
  en: Vehicle
  fr: Véhicule
class_type: ITEM_CLASS
superclass: UNIVERSE
applicable_properties:
  - vehicle_length
  - vehicle_weight
```

This is "fully native to CDD ontology" — semantic attribute names,
multilingual as nested Hash, sets as Arrays. No MDC_P### keys.

## Scope

- `lib/opencdd/model/yaml_entity.rb` — typed lutaml-model class
- `lib/opencdd/model/yaml_database.rb` — database-level YAML wrapper
- `lib/opencdd/model.rb` — namespace autoload
- Conversion methods on Entity and Database
- Specs for YAML round-trip

## Acceptance

- [x] lutaml-model dependency added
- [x] YamlEntity with typed CDD-native attributes
- [x] Database#to_yaml / Database.from_yaml
- [x] OceanRunner round-trips through YAML
- [x] All 813 existing specs pass
