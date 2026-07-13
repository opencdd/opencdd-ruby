# Plan 34 — Per-entity YAML persistence with lutaml-store

## Why

YAML is the canonical persistence format (plan 33). Per-entity YAML
files make dictionaries diff-friendly at the entity level — one
`git diff` shows exactly which entity changed. `lutaml-store`
provides the store infrastructure (CRUD, model registry, filesystem
backend, multi-format I/O) so we don't hand-roll directory traversal.

## Scope

- Add `lutaml-store` dependency
- Register `Opencdd::Model::YamlEntity` with `Lutaml::Store`
- `Database#save_to_directory(path)` — one `.yaml` per entity
- `Database.load_from_directory(path)` — reads back
- Directory layout: `entities/<type>/<code>.yaml`

## Directory layout

```
data/
└── entities/
    ├── class/
    │   ├── AAA001.yaml
    │   └── AAA010.yaml
    ├── property/
    │   └── AAAP001.yaml
    └── value_list/
        └── AAAE001.yaml
```

Each file is a single `YamlEntity` serialized via lutaml-model.

## Approach

```ruby
db.save_to_directory("data/")     # writes per-entity YAML files
db2 = Opencdd::Database.load_from_directory("data/")  # reads them back
```

Internally uses `Lutaml::Store` with filesystem adapter and
`YamlEntity` as the registered model.

## Acceptance

- [x] `lutaml-store` dependency added
- [x] `save_to_directory` writes one YAML per entity
- [x] `load_from_directory` reads them all back
- [x] OceanRunner round-trips through directory persistence
- [x] All existing specs pass

## Dependencies

- Plan 33 (lutaml-model YAML adapter)
