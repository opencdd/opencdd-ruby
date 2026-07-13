# Plan 35 — Entity extends Lutaml::Model::Serializable

## Why

Currently `Opencdd::Entity` uses a `Hash<String,String>` for storage
and the Field DSL provides typed accessors over it. Plan 33 added a
separate `YamlEntity` adapter. The user wants Entity itself to be a
Lutaml::Model::Serializable — typed attributes as the canonical store,
`properties` Hash as a derived view.

This deepens the model: one representation, not two (Entity + YamlEntity).
Framework-provided serialization, validation hooks, and type coercion.

## Scope

- `Opencdd::Entity < Lutaml::Model::Serializable`
- Typed `attribute` declarations replace `properties` Hash as canonical
- `properties` Hash becomes a computed view over typed attributes
- Field DSL delegates to lutaml-model attributes
- CDDAL/Parcel readers construct typed entities (bridge via `from_properties`)

## Approach

Phase 1: Add lutaml-model attributes alongside existing Hash storage.
Phase 2: Make typed attributes canonical; Hash derives from them.
Phase 3: Remove YamlEntity adapter (Entity IS the yaml model).
Phase 4: Use lutaml-store for persistence.

This plan covers Phase 1-2. Phase 3-4 are incremental follow-ups.

## Acceptance

- [x] Entity extends Lutaml::Model::Serializable
- [x] Typed attributes declared for common fields
- [x] `properties` Hash derives from typed attributes
- [x] Entity#to_yaml works natively (no YamlEntity adapter needed)
- [x] All 825+ specs pass

## Dependencies

- Plan 33 (lutaml-model YAML adapter — proves the attribute shape)
- Plan 34 (lutaml-store — uses Entity as registered model)
