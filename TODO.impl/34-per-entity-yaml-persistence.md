# Plan 34 — Per-entity YAML persistence with lutaml-store

## Why

YAML is the canonical persistence format (plan 33). Per-entity YAML
files make dictionaries diff-friendly at the entity level — one
`git diff` shows exactly which entity changed.

The current `EntityStore` (85 lines) uses `Lutaml::Store` but bypasses
its API — calling `store.store.adapter.set/get` directly. This is a
shallow use of the framework: we get the filesystem adapter but none
of the model registry, CRUD, or polymorphic dispatch benefits.

The deepening: register Entity as a model with `DatabaseStore` and
use the CRUD API (`save`, `fetch`, `all`) properly. After plan 35,
Entity IS the `Lutaml::Model::Serializable`, so it plugs in directly.

## Directory layout

```
data/
├── AA/
│   ├── AAA001.yaml
│   └── AAA001.meta
├── AB/
│   └── ABB002.yaml
└── ...
```

The FileSystem adapter shards by the first 2 chars of the key for
scalability (avoids directory-size limits on large dictionaries like
iec61987 with 11,831 entities). Extension configured as `.yaml`.

The `.meta` sidecar carries SHA256 integrity metadata — tamper
detection for dictionary data.

## Key scheme

Each entity's storage key is its IRDI code (e.g., `AAA001`), prefixed
with the entity type for uniqueness (codes can collide across types):

```ruby
def storage_key
  "#{type}/#{code}"
end
```

The FileSystem adapter sanitizes this to `class_AAA001` (replacing `/`
with `_`), stored at `cl/class_AAA001.yaml`.

## Approach

```ruby
db.save_to_directory("data/")      # writes per-entity YAML files
db2 = Opencdd::Database.load_from_directory("data/")  # reads them back
```

Internally:
1. Create a `Lutaml::Store` with `DatabaseStore` and FileSystem adapter
2. Register `Opencdd::Entity` with polymorphic mapping
3. `save_database` iterates entities, calls `store.save(entity)`
4. `load_database` calls `store.all(Entity)`, feeds results into Database

## Polymorphic dispatch

The store registers `Opencdd::Entity` as the base model with a
polymorphic discriminator (`type` attribute) mapping to subclasses:

```ruby
models: [{
  model: Opencdd::Entity,
  key: :storage_key,
  polymorphic: {
    discriminator: :type,
    mapping: {
      class: Opencdd::Klass,
      property: Opencdd::Property,
      unit: Opencdd::Unit,
      value_list: Opencdd::ValueList,
      value_term: Opencdd::ValueTerm,
      relation: Opencdd::Relation,
      view_control: Opencdd::ViewControl,
    }
  }
}]
```

The `ModelSerializer` stores `_class` metadata in each record for
type-safe deserialization.

## Acceptance

- [ ] EntityStore uses `DatabaseStore#save` / `#all` (not adapter.set/get)
- [ ] Entity registered with polymorphic dispatch by `type`
- [ ] Directory layout: sharded by first 2 chars, `.yaml` extension
- [ ] `save_to_directory` writes one YAML per entity
- [ ] `load_from_directory` reads them all back via `store.all`
- [ ] OceanRunner round-trips through directory persistence
- [ ] `.meta` integrity sidecars generated
- [ ] All existing specs pass

## Dependencies

- Plan 35 (Entity as Lutaml::Model::Serializable — the registered model)
