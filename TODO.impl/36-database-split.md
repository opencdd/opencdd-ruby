# Plan 36 — Database class split

## Why

Database is 719 lines, mixing entity storage, Parcel integration,
graph queries, mutations, finalization, and YAML persistence. After
plan 34 (lutaml-store handles persistence) and plan 35 (Entity is a
typed model), Database can slim down to a facade over the store +
graph invariants.

## Current responsibilities (by method count)

| Concern              | Methods                                            | Lines |
|----------------------|----------------------------------------------------|-------|
| Entity storage/index | add_entity, find, find_by_code, entities, count    | ~80   |
| Parcel integration   | add_workbook, add_dictionary, drop_dictionary, ... | ~120  |
| Graph queries        | categorical_classes, instances_of, properties_of   | ~100  |
| Graph finalization   | finalize!, link_class_hierarchy!, link_property_*  | ~90   |
| Mutations            | rename_entity, merge, apply_change_request, remove | ~90   |
| Reference resolution | resolve_reference, coerce_entity, coerce_irdi      | ~50   |
| Persistence          | to_yaml, from_yaml, save_to_directory, ...         | ~30   |
| Symbol table         | register_symbol, bind_symbol, rebuild_symbol_table | ~40   |
| Misc                 | to_s, inspect, each, etc.                          | ~30   |

## Target architecture

Split into focused modules mixed into Database. Each module is a
concern, in its own file under `lib/opencdd/database/`.

```
lib/opencdd/
├── database.rb                    # Core: identity, indexing, initialize
├── database/
│   ├── parcel_integration.rb      # add_workbook, add_dictionary, ...
│   ├── queries.rb                 # find, coerce, powertype API, walkers
│   ├── finalization.rb            # finalize!, link_* methods
│   ├── mutations.rb               # rename_entity, merge, apply_change_request
│   └── persistence.rb             # to_yaml, from_yaml, save/load_directory
```

### Database (core) — ~200 lines

```ruby
class Database
  include Enumerable
  include Opencdd::Database::ParcelIntegration
  include Opencdd::Database::Queries
  include Opencdd::Database::Finalization
  include Opencdd::Database::Mutations
  include Opencdd::Database::Persistence

  attr_reader :workbooks, :unresolved_refs, :alias_table

  def initialize
    # Initialize all indexes
  end

  # Entity storage: add_entity, entities, count, each
  # Type-partitioned accessors: classes, properties, units, ...
end
```

### ParcelIntegration — ~120 lines

Workbook ingestion, dictionary lifecycle (add/drop/register_external),
sheetmap construction, translation-language parsing.

### Queries — ~100 lines

`find`, `find_by_code`, `find_by_name`, `resolve_reference`,
`coerce_entity`, `coerce_irdi`, powertype API (`categorical_classes`,
`instances_of`, `valid_class_reference?`), graph walkers
(`properties_of`, `classes_with_property`, `value_list_of`,
`relations_for`, `functions_involving`), tree accessors.

### Finalization — ~90 lines

`finalize!`, `normalize_reference_collections!`,
`each_reference_collection`, `link_class_hierarchy!`,
`link_property_classes!`, `link_value_lists!`, `rebuild_symbol_table!`.

### Mutations — ~90 lines

`rename_entity`, `merge`, `apply_change_request`, `remove_by_irdi`,
`apply_view_control`, back-reference rewriting.

### Persistence — ~30 lines

`to_yaml`, `from_yaml`, `save_to_directory`, `load_from_directory`.
Thin delegates to `EntityStore` and `YamlDatabase` (or directly to
Entity after plan 35).

## Module shared state

Modules access Database's internal state through `attr_reader`
accessors on the core class. No `instance_variable_get` across
objects (encapsulation rule). Each module documents which readers
it depends on.

## Acceptance

- [x] `database.rb` under 250 lines (core only) — 150 lines
- [x] Each concern in its own file under `lib/opencdd/database/`
- [x] All modules use autoload from `lib/opencdd/database.rb`
- [x] No `send` to private methods across modules
- [x] No `instance_variable_get/set` across objects
- [x] No `require_relative` (autoload only)
- [x] All 835+ specs pass unchanged
- [x] Database#public_methods surface unchanged (pure refactor)

## Dependencies

- Plan 34 (persistence module delegates to EntityStore)
- Plan 35 (Entity as typed model simplifies entity handling)
