# Plan 05 — Database (in-memory store + indexes + mutations)

## Why

The `Cdd::Database` is the canonical in-memory representation of a CDD
dictionary (or a merge of several). All format readers populate one, all
writers serialize one, the validator walks one, all interactive commands
mutate one. It owns entity identity, reverse indexes, and the mutation
commands that preserve invariants.

The class already exists (`lib/cdd/database.rb`, ~620 lines). This plan
locks down its public API and enumerates the indexes and mutations
required by ParcelMaker parity.

## Scope

- Public API surface of `Cdd::Database`.
- Idempotent `finalize!` (build reverse indexes).
- Mutations: `add_entity`, `merge`, `rename_entity`, `remove_entity`,
  `drop_dictionary`, `apply_change_request`.
- Reverse indexes (single-owner, rebuilt on finalize).
- Semantic equality (`semantically_equal?`).

Not in scope: entities themselves (plan 03), format readers/writers
(plans 06–08), validation (plan 10).

## Approach

### Construction and identity

```ruby
db = Cdd::Database.new
db.add_entity(klass)
db.add_entity(property)
db.finalize!
db.finalize!   # idempotent — second call is a no-op
```

`Database` does **not** own a `Project` sheet or `pcls_LOCAL` directly —
those live on `Cdd::Parcel::Workbook` (plan 06). The Database is the
entity-graph view; the Workbook is the on-disk-shape view.

### Public API — read

| Method | Returns |
|--------|---------|
| `entities` | `Array<Cdd::Entity>` |
| `classes` / `properties` / `units` / `value_lists` / `value_terms` / `relations` / `view_controls` | filtered |
| `find(irdi)` | `Cdd::Entity` or nil |
| `find_by_code(code, type: nil)` | `Cdd::Entity` or nil |
| `find_by_meta_class(meta_class_irdi)` | `Array<Cdd::Entity>` |
| `root_classes` | classes with no parent |
| `children_of(klass)` | `Array<Cdd::Klass>` |
| `subclasses_of(klass)` | recursive descendants |
| `instances_of(klass)` | classes whose `is_case_of` includes `klass` |
| `properties_of(klass)` | declared + imported properties |
| `effective_properties_of(klass)` | via `Cdd::EffectiveProperties` (walks hierarchy + is_case_of) |
| `value_list_of(property)` | resolves the value list for ENUM properties |
| `relations_for(domain: nil, codomain: nil)` | filtered |
| `composition_tree(klass)` | via `Cdd::CompositionTree` |
| `class_tree` / `relation_tree` | tree walkers |
| `semantically_equal?(other)` | bool — value equality, ignoring order |

### Public API — mutate

```ruby
db.add_entity(entity)              # idempotent on IRDI; updates indexes if finalized
db.merge(other_db)                 # union of entities; later wins on conflict
db.rename_entity(old_code, new_code)  # rewrites every back-reference
db.remove_entity(irdi)             # removes + cleans back-refs
db.drop_dictionary(dict_id)        # removes entities belonging to dict
db.apply_change_request(request)   # upserts + removals as a single transaction
db.finalize!                       # (re)build reverse indexes; idempotent
```

Mutation rules:
- Mutations before `finalize!` are allowed; mutations after require
  updating indexes incrementally or calling `finalize!` again.
- Mutations preserve the frozen-entity invariant: replacing an entity
  means constructing a new one and updating its back-references; never
  mutate the old instance.
- All mutations return `self` for chaining.

### Reverse indexes

Built once on `finalize!`. Each is a `Hash` keyed by IRDI:

- `by_irdi` — entity lookup.
- `by_code` — short-code lookup (scoped by entity type).
- `by_type` — `Hash{ Symbol => Array<Entity> }`.
- `children_of` — `Hash{ class_irdi => Array<Klass> }`.
- `subclasses_of` — memoized recursive descent.
- `declared_properties_by_class` — `Hash{ class_irdi => Array<Property> }`.
- `properties_by_value_list` — `Hash{ vl_irdi => Array<Property> }`.
- `properties_by_unit` — `Hash{ unit_irdi => Array<Property> }`.
- `relations_for_class_domain` — `Hash{ class_irdi => Array<Relation> }`.
- `relations_for_class_codomain` — same, codomain.
- `instances_of` — `Hash{ klass_irdi => Array<Klass> }` (reverse of
  `is_case_of`).
- `controlling_properties` — `Hash{ property_irdi => Array<Property> }`
  (reverse of `condition`).

A single `build_reverse_index(database) { |entity| ... }` helper generates
all of them (DRY). Already in the browser bundle per the project
CLAUDE.md — port the pattern.

### EffectiveProperties (lib/cdd/effective_properties.rb)

Walks a `Klass`'s ancestor chain (via `parent_irdi`) **and** every
`is_case_of` target, collecting applicable + imported properties. Used by
Parcel export to populate the "effective" sheet for a class. Cycle-safe —
tracks visited IRDIs.

### Mutation details

#### `add_entity(entity)`

- If `by_irdi[entity.irdi]` exists and is `!= entity`, replace and
  re-sync indexes.
- If `entity.type == :class` and `entity.parent_irdi` is set, register
  in `children_of[parent_irdi]`.
- Sets `entity.database = self` (transient back-pointer).
- Returns `self`.

#### `merge(other_db)`

- Iterates `other_db.entities`; calls `add_entity` on each.
- On IRDI conflict, the `other_db` version wins (callers should pass the
  higher-priority database second).
- Re-finalizes if both sides were finalized.

#### `rename_entity(old_code, new_code)`

- Finds the entity by `old_code`.
- Constructs a new entity (same class) with the code property updated.
- Walks every back-reference (`parent_irdi`, `is_case_of_irdis`,
  `applicable_property_irdis`, `imported_property_irdis`,
  `sub_class_selection_irdis`, `definition_class_irdi`, `unit_irdi`,
  `alternative_unit_irdis`, condition references, relation domain/codomain,
  view-control controlled/shown) and rewrites the old IRDI to the new.
- Atomic: collects all rewrites; if any fails, rolls back.

This is ParcelMaker feature F27.

#### `apply_change_request(request)`

`request` is a struct of `upserts: Array<Entity>` and `removals:
Array<IRDI>`. Applies upserts and removals as a single transaction.
On any error, no mutation is committed. Used by the import pipeline
(`Cdd::Database.load_change_request`).

### Semantic equality

`db1.semantically_equal?(db2)` returns true iff:
- Same set of IRDIs.
- For each IRDI, same meta-class, same code, same raw properties (after
  canonicalizing set ordering).
- Order of declarations is **not** significant.

Used by every round-trip spec in plan 12.

## Acceptance criteria

- [ ] `Database.new.add_entity(e).find(e.irdi) == e`.
- [ ] `Database#finalize!` idempotent (guarded by `@finalized` flag).
- [ ] `db.merge(other)` preserves entities from both, with `other`
      winning on conflict.
- [ ] `rename_entity` rewrites every back-reference type listed above.
      Spec covers each one.
- [ ] `apply_change_request` is transactional.
- [ ] `effective_properties_of` walks `is_case_of` and the superclass
      chain; cycle-safe.
- [ ] `semantically_equal?` true after parse → serialize → parse on the
      OceanRunner fixture.
- [ ] `spec/database_spec.rb`, `spec/database_*_spec.rb`,
      `spec/effective_properties_spec.rb` green.

## Dependencies

- **Plan 03** — entity classes.
- **Plan 04** — IRDI / property IDs / meta-classes.
- Blocks **plan 06** (Parcel readers call `add_entity`), **plan 07**
  (CDDAL Builder calls `add_entity`), **plan 10** (validator walks),
  **plan 12** (round-trip uses `semantically_equal?`).

## Open questions

- **Q1.** Should `Database` be thread-safe? **Recommendation:** no — the
  gem is single-threaded by design; concurrent access is the caller's
  responsibility.
- **Q2.** Should `apply_change_request` support partial success
  (`dry_run:` flag returning a preview)? **Recommendation:** yes —
  needed for the editor's "preview import" UX in a future phase.
