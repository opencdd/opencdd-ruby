# Plan 36 — Database class split

## Why

Database is 690 lines, mixing entity storage, Parcel integration,
graph queries, mutations, finalization, and YAML persistence. With
lutaml-store handling storage (plan 34), the Database can slim down
to a facade over the store + graph invariants.

## Scope

Extract concerns into focused modules:

- `Database` (core): entity identity, indexing, finalize!, semantically_equal?
- `Database::ParcelIntegration`: add_workbook, add_dictionary, register_external_sheet
- `Database::Queries`: powertype API, effective_properties, coercion, graph walkers
- `Database::Persistence`: save_to_directory, load_from_directory, to_yaml, from_yaml

## Approach

Mixin modules on Database. Each module adds methods via `include`.
Shared state stays on Database; modules access it through the public
interface or documented private helpers.

## Acceptance

- [x] Database.rb under 400 lines
- [x] Each concern in its own file
- [x] All 825+ specs pass
- [x] No new forbidden patterns

## Dependencies

- Plan 34 (lutaml-store integration — provides storage alternative)
- Plan 35 (Entity as Lutaml::Model — simplifies Database's entity handling)
