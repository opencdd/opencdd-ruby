# lutaml-model Migration — Phased Plan

**Parent proposal:** [`19-condition-grammar-and-lutaml-migration.md`](19-condition-grammar-and-lutaml-migration.md)
**Decisions resolved:** 2026-07-23
**Status:** ready to execute

This document expands the Phase 2.1–2.5 scope from the parent proposal
into a fully-decisioned plan. Each phase lists: scope, files to change,
how the three user decisions apply, acceptance criteria, and risks.

---

## User decisions applied throughout

1. **Per-item + single-file layouts coexist.** Per-item is the default
   for new work and for `git`-tracked dictionaries (entity-level diffs).
   Single-file remains available for ad-hoc exports, CI fixtures, and
   the `import` directive in CDDAL modules. Both formats share one
   serialization layer (`Entity::Yaml`).

2. **YAML is the default wire format.** JSON is supported as an
   `adapter:` / `format:` override on every persistence entry point.
   No second model class — only the lutaml adapter swaps.

3. **Multilingual fields use nested maps in YAML and JSON.** Shape:
   `preferred_name: { en: "...", fr: "..." }`. The flat keyed shape
   (`MDC_P004.en = "..."`) exists **only** inside Parcel `.xlsx`
   (which has its own column schema) and inside the in-memory
   `@properties` Hash (where it stays as the wire-format view).

---

## Phase 2.1 — Foundation: lutaml-model dep + `Unit` reference port

**Status:** Already shipped via TODO.impl/33 and TODO.impl/35. Listed
here for completeness; new work below builds on this foundation.

### What landed
- `lutaml-model` and `lutaml-store` declared in `opencdd.gemspec`.
- `Opencdd::Entity::Yaml` is a `Lutaml::Model::Serializable` subclass
  with CDD-native attribute names (`preferred_name`, `class_type`, etc.)
  driven from `Entity::FieldRegistry`.
- `Opencdd::Model::YamlDatabase` wraps a whole database as a single
  YAML document via lutaml-model.
- `Opencdd::Model::EntityStore` writes per-entity YAML files via
  lutaml-store's `DatabaseStore`.

### Why `Unit` as the reference port
Smallest entity (no multilingual expansions, no class hierarchy, no
references) — ideal for proving the typed-attribute shape end-to-end
before replicating across the six larger entities.

### Acceptance (already met)
- [x] `bundle exec rspec` — all 607+ specs pass.
- [x] `Unit#to_yaml` / `Unit.from_yaml` round-trip without data loss.
- [x] No `def to_h` / `from_h` / `to_hash` on the model class.
- [x] No `require_relative` in library code (autoload only).

---

## Phase 2.2 — Port remaining 6 entities

**Status:** Already shipped. All entity types (ValueTerm, ValueList,
Property, Klass, Relation, ViewControl, ListOfUnit) inherit through
`Entity::Yaml`. Field-DSL declarations on each subclass flow into the
YAML model automatically via the FieldRegistry walk in
`Entity::Yaml.from_entity`.

### What's in place
- `Entity::Yaml.from_entity` walks `FieldRegistry.fields_for(entity.class)`
  and writes each field's value to the matching YAML attribute.
- Polymorphic dispatch lives on the `type` attribute (`:class`,
  `:property`, etc.). `Entity::Yaml.to_entity` consults
  `Opencdd::MetaClasses.entity_class_for_type` for the inverse mapping.
- The `extra` Hash catches any property ID not declared in the field
  DSL, preserving lossless import for unknown Parcel columns.

### Decisions applied
- **Multilingual as nested map.** `extract_ml` returns
  `{ "en" => "Vehicle", "fr" => "Véhicule" }` for storage; `merge_ml`
  re-flattens to `MDC_P004.en = "..."` keys on the way back into
  `@properties`. The flat shape never appears on disk.

### Acceptance (already met)
- [x] Each entity type round-trips through YAML.
- [x] OceanRunner fixture round-trips end-to-end.
- [x] `bundle exec rspec` — all specs pass.

### Open gap to close in 2.3 (not blocking 2.2)
- The YAML model is a sibling class (`Entity::Yaml`), not Entity
  itself. Plan 35's "fold adapter into Entity" is not yet complete —
  Entity still owns the `@properties` Hash as canonical store, with
  `Entity::Yaml` as a deepened adapter. This is acceptable but means
  every persistence call goes through `from_entity` / `to_entity`
  conversion. Folding the adapter INTO Entity remains a future
  architectural cleanup, gated on lutaml-model's ivar-reading
  constraint being compatible with the field-DSL pattern.

---

## Phase 2.3 — Replace CDDAL serializer/builder with lutaml adapter

**Status:** Not started. **Estimated delta:** ~−200 LOC net.

### Current state
`lib/opencdd/cddal/serializer.rb` (~300 LOC) is hand-rolled: it walks
each entity type, formats fields as CDDAL syntax, and emits a single
text document. The lexer/parser/racc grammar (`cddal.y`,
`generated_parser.rb`, `lexer.rb`) parse CDDAL into AST nodes
(`lib/opencdd/cddal/ast.rb`); the builder (`lib/opencdd/cddal/builder.rb`)
walks AST → Entity. Both are necessary and stay.

### What changes
| File | Change |
|------|--------|
| `lib/opencdd/cddal/serializer.rb` | Replace hand-rolled emit with a thin lutaml-style adapter: walk typed attributes on `Entity::Yaml`, render each as CDDAL syntax. Reuse `value_serializer.rb` for the existing literal/set/tuple formatting. |
| `lib/opencdd/cddal/builder.rb` | Unchanged — already uses typed assignments. |
| `lib/opencdd/cddal/value_serializer.rb` | Unchanged — primitives (`Literal`, `Set`, `Tuple`, `ClassReference`) are format-neutral. |
| `lib/opencdd/cddal/cddal.y`, `generated_parser.rb`, `lexer.rb` | Unchanged — grammar is the wire contract. |
| `spec/cddal_spec.rb` | Add round-trip cases for every entity type (some exist; fill gaps). |

### Decisions applied
- **YAML default + JSON override.** CDDAL is a third wire format,
  independent of YAML/JSON. The serializer refactor uses the same
  typed-attribute source as YAML — `Entity::Yaml` — so the three
  formats converge on one model.
- **Per-item + single-file coexist.** CDDAL `include` directives
  (parsed by `lib/opencdd/cddal/resolver.rb` and
  `lib/opencdd/cddal/fetcher/`) already let a single-file CDDAL
  document pull in per-item YAML/CDDAL files. The refactor preserves
  this — the resolver stays, only the emit layer changes.

### Acceptance
- [ ] `bundle exec rspec` — all specs pass.
- [ ] CDDAL round-trip on OceanRunner fixture: parse → serialize → parse
  yields semantically equal databases.
- [ ] CDDAL round-trip on iec62683 fixture: class-reference conditions
  (Phase 1 of this TODO) survive intact.
- [ ] Serializer file drops below 150 LOC (from ~300).
- [ ] No `def to_h` / `from_h` / `to_hash` on the model class.

### Risks
- The hand-rolled serializer currently handles edge cases
  (empty-value omission, multilingual expansion, set quoting) that
  the typed-attribute walk may not cover. Mitigation: keep
  `value_serializer.rb` intact; only the entity-walking loop changes.

---

## Phase 2.4 — Per-item file layout with type-partitioned subdirectories

**Status:** Not started. **Estimated delta:** ~+150 LOC.

### Current state
`Model::EntityStore` writes per-entity YAML files into a flat
`entities/<sanitized-irdi>.yaml` directory via lutaml-store's
`:separate` layout. The flat shape works but doesn't match the
TODO 19 spec, which calls for type-partitioned subdirectories:

```
my_dictionary/
├── _meta.yaml
├── classes/
│   ├── AAA001.yaml
│   └── AAA002.yaml
├── properties/
│   └── ABA001.yaml
├── units/
├── value_lists/
├── value_terms/
├── relations/
├── view_controls/
└── list_of_units/
```

### What changes
| File | Change |
|------|--------|
| `lib/opencdd/model/entity_store.rb` | Switch from `:separate` layout to manual per-type subdirectories. The store keeps its `Lutaml::Store` backend for CRUD, but the filesystem shape is `<root>/<type_plural>/<code>.yaml`. Add a `_meta.yaml` writer for dictionary-level metadata (source language, translation languages, parcel_id, generated_at). |
| `lib/opencdd/model/directory_layout.rb` | **New.** Single source of truth for `type → plural_directory` mapping (`:class → "classes"`, `:property → "properties"`, etc.). Used by both writer and reader so they cannot drift. |
| `lib/opencdd/database/persistence.rb` | Add `dump_to_dir(path, format: :yaml)` and update `save_to_directory` to call it. `load_from_dir(path)` reads the new layout; `load_from_directory` stays as a back-compat alias that detects old vs new layout by presence of `_meta.yaml`. |
| `lib/opencdd/model/yaml_database.rb` | Unchanged — still provides the single-file YAML shape. Single-file stays supported per Decision 1. |
| `lib/opencdd/database.rb` | Add `Database.dump_to_dir` / `Database.load_from_dir` class methods delegating to EntityStore. |
| `spec/model/entity_store_spec.rb` | Add round-trip specs for the new layout; verify `_meta.yaml` contents. |

### File naming
- Code-only filename (`AAA001.yaml`), not full IRDI. The full IRDI
  is the first field inside the file; the path is `type_plural/code`.
- Codes with non-alphanumeric characters (e.g., codes with `_`) pass
  through unchanged. Codes containing `/` would collide with the
  type-directory path; none observed in the IEC CDD code registry
  (codes match `^[A-Z]{3}[0-9]{3}$` historically).

### `_meta.yaml` shape
```yaml
---
parcel_id: IEC62683
source_language: en
translation_languages:
  - fr
  - de
generated_at: 2026-07-23T10:00:00Z
entity_counts:
  classes: 1855
  properties: 1200
  units: 30
  value_lists: 12
  value_terms: 500
  relations: 40
  view_controls: 0
  list_of_units: 0
schema_version: "1"
```

### Decisions applied
- **Per-item default.** `Database.dump_to_dir(path)` writes the
  per-item layout above. `Database#to_yaml` (single-file) stays
  available for ad-hoc use — Decision 1's coexistence.
- **YAML default + JSON override.** `dump_to_dir(path, format: :yaml)`
  is the default; `dump_to_dir(path, format: :json)` writes
  `<code>.json` files instead. Both share the same `Entity::Yaml`
  model — only the lutaml adapter swaps.
- **Multilingual as nested map.** Per-entity YAML already emits
  `preferred_name: { en: ..., fr: ... }`. The new layout preserves
  this; no flattening at the file boundary.

### Acceptance
- [ ] `Database.load_from_dir(db.dump_to_dir(tmp))` is semantically
  equal to `db` (uses `Database#semantically_equal?`).
- [ ] Per-entity files land in the correct type-partitioned subdir.
- [ ] `_meta.yaml` is written and read; counts match the actual
  entity totals.
- [ ] JSON layout round-trips equivalently (`format: :json`).
- [ ] `bundle exec rspec` — all specs pass.
- [ ] OceanRunner fixture round-trips through the new layout.

### Risks
- The current flat layout is referenced by `spec/model/entity_store_spec.rb`
  and by `Database.load_from_directory` callers. Mitigation:
  `load_from_directory` detects layout by `_meta.yaml` presence and
  dispatches to old-flat vs new-partitioned reader. Remove the
  old-flat reader only after one release cycle.

---

## Phase 2.5 — Collapse `Exporters::Json` / `Yaml` to thin wrappers

**Status:** Not started. **Estimated delta:** ~−100 LOC net.

### Current state
`lib/opencdd/exporters/json.rb` (~200 LOC) and
`lib/opencdd/exporters/yaml.rb` (~50 LOC) hand-roll payloads: they
walk each entity type, build a Hash, and pass it to `JSON.generate`
or `YAML.dump`. The hand-rolled payloads duplicate the
wire-name mapping that `Entity::Yaml` already declares via lutaml-model
attributes.

### What changes
| File | Change |
|------|--------|
| `lib/opencdd/exporters/json.rb` | Replace hand-rolled `entity_payload` / `database_payload` with `entity.yaml.to_json` / `database.yaml.to_json`. Keep the public `export(entity, database:)` signature. The registry-dispatched `payload_for(entity, database:)` stays — it's the per-entity hook used by `rake browser:build`. |
| `lib/opencdd/exporters/yaml.rb` | Replace hand-rolled emit with `database.to_yaml` (already delegates to `YamlDatabase`). Becomes a 10-line wrapper. |
| `lib/opencdd/exporters.rb` | Unchanged — autoload entries stay. |
| `spec/exporters/*` | Update expectations if the JSON field ordering changes. Lutaml-model emits in attribute-declaration order; current exporters emit in a different (hand-curated) order. Either redeclare attribute order or relax the specs to compare parsed JSON, not raw strings. |

### Decisions applied
- **YAML default + JSON override.** Both thin wrappers delegate to
  lutaml-model's `to_yaml` / `to_json`, which share one typed model.
  No second code path for JSON.
- **Multilingual as nested map.** lutaml-model emits the Hash
  attribute as-is, producing the nested `{ "en": "...", "fr": "..." }`
  shape in both YAML and JSON. The current hand-rolled JSON exporter
  emits the same shape (Decision 3 is already satisfied here; this
  phase just removes the duplication).

### Acceptance
- [ ] `bundle exec rspec` — all specs pass (some specs may need to
  compare parsed JSON rather than raw strings if attribute order
  differs from the hand-rolled version).
- [ ] `rake browser:build[iec62683]` produces semantically equal JSON
  output (parse both old and new, compare Hash equality).
- [ ] `Exporters::Json` file drops below 80 LOC.
- [ ] `Exporters::Yaml` file drops below 20 LOC.
- [ ] No `def to_h` / `from_h` / `to_hash` on the model class.

### Risks
- Browser JSON consumers may rely on field ordering. JSON field order
  is technically not semantic, but some consumers parse with
  ordered-hash expectations. Mitigation: audit
  `browser/src/data/loaders.ts` and any editor-side JSON parsing;
  pin attribute order in `Entity::Yaml` to match the current
  exporter's order if any consumer is order-sensitive.

---

## Cross-phase verification gates

These gates run after every phase, not just at the end.

1. **`bundle exec rspec`** — all 607+ specs pass. No new exclusions.
2. **`Database.load_from_dir(db.dump_to_dir(tmp))` semantically equal
   to `db`** — round-trip invariant for every entity type.
3. **Each entity round-trips YAML and JSON** — both formats share one
   model, so a single round-trip test per format suffices.
4. **Zero `def to_h` / `def from_h` / `def to_hash` in `lib/`** —
   enforced by `spec/code_quality_spec.rb`. Add a grep assertion if
   not already present.
5. **CDDAL round-trip on OceanRunner fixture** — Phase 2.3's primary
   acceptance gate.
6. **`rake browser:build[iec62683]` produces semantically equal JSON** —
   Phase 2.5's primary acceptance gate. Compare parsed Hash equality,
   not raw string equality, to allow attribute-order drift.

---

## Sequencing

```
2.1 ✅ (done) ──► 2.2 ✅ (done) ──► 2.3 (CDDAL serializer refactor)
                                      │
                                      ▼
                                   2.4 (per-item layout)
                                      │
                                      ▼
                                   2.5 (exporter collapse)
```

Phases 2.3 and 2.4 are independent and can run in parallel once 2.2
lands (which it has). Phase 2.5 depends on 2.4 (the JSON exporter
thin-wrapper delegates to `Entity::Yaml#to_json`, which is format-
agnostic — but the per-item JSON writer in 2.4 is the proof that
JSON output works for the layout).

---

## What this plan does NOT change

- **Parcel `.xlsx` format.** The Parcel reader/writer
  (`lib/opencdd/parcel/`) is unaffected. Parcel is a separate wire
  format with its own column-based schema; multilingual fields stay
  flat there (Decision 3 carve-out).
- **In-memory `@properties` Hash.** Entity continues to use the Hash
  as the canonical read store during this migration. Folding the
  YAML adapter into Entity (Plan 35's full vision) is a future
  architectural cleanup, not part of TODO 19.
- **Validator rules.** `lib/opencdd/validator/` is unaffected — it
  operates on the in-memory model, not on serialized forms.
- **Editor (TS) model port.** Browser/editor TypeScript types mirror
  the Ruby model's wire shape. As long as the wire shape is stable
  (which this plan guarantees — same YAML/JSON attribute names),
  no TS changes are required.
