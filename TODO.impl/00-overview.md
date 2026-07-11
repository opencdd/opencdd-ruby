# TODO.impl — OpenCDD Ruby: full implementation plan

## What this is

A plan to take the `opencdd` Ruby gem from its current extracted state to a
complete, spec-conformant implementation of:

1. The IEC 61360 / IEC 62656-1 CDD ontology model.
2. The Parcel Excel format (read + write, full ParcelMaker 5.2.1 parity).
3. The CDDAL plain-text format (parse + serialize + round-trip).
4. CDDAL split-file / module system (cross-file references by path or URL).
5. The CDDAL specification document, authored in Metanorma, in a new
   `opencdd/cddal-spec` repository.

The plan is split into scoped, MECE sub-plans (`01`–`15`). Each sub-plan
states its **why**, **scope**, **approach**, **acceptance criteria**, and
**dependencies**.

## Starting state (2026-07-11)

The repo at `/Users/mulgogi/src/opencdd/opencdd-ruby` already contains a
substantial extraction of a working `cdd` gem:

- `lib/cdd/` — 50+ Ruby files: entities, identifiers, database, parcel
  readers/writer, CDDAL lexer/parser/builder/serializer, validator rule
  classes, exporters.
- `spec/` — 41 spec files including `spec/parcel/*` and a CDDAL spec
  driving the OceanRunner fixture.
- `reference-docs/` — ParcelMaker manuals, IEC 61360 markdown, Parcel
  xlsx/xls fixtures, the Kagoshima CDDAL sample, the OceanRunner example.
- `opencdd.gemspec` — published as `opencdd`, internal module still `Cdd`.

What's **not** done, derived from `cdd-data/specs/parcelmaker/`:

- **Property registry discrepancies** (see plan 02). The cdd-data spec
  enumerates ~11 wrong alias→ID mappings and one wrong meta-class IRDI
  (Relation should be `MDC_C011`, not `MDC_C006`). These are bugs.
- **CDDAL split-file system** (see plan 09). The current `import_decl`
  only takes a string and is skipped on HTTPS. No qualified imports,
  no selective imports, no cycle detection, no source-location tracking.
- **CDDAL specification** (see plan 13). The draft at
  `cdd-data/reference-docs/specs/cddal-v1.adoc` is a starting point but
  lives in the wrong repo, predates the module system, and has its own
  inconsistencies (e.g. says `imported_properties` is `MDC_P040`).
- **Audit/parity gaps** in Parcel sheet scaffolding (F03), instance-data
  generation (F10), rename (F27), view-control application (F18) — see
  plans 06 and 10.

## Principles (non-negotiable)

These come from the global CLAUDE.md and the project CLAUDE.md. Every plan
inherits them; they are restated in plan 01.

- **NEVER delete source files.** `reference-docs/`, `downloads/`, the
  ParcelMaker MSI / PDF / xlsx, the Kagoshima sample, IEC PDFs — all
  source. Cleanup suggestions only; never `rm` without confirmation.
- **NEVER push tags, NEVER push to main, NEVER commit to main.** All
  work goes through PRs on feature branches.
- **NEVER add AI attribution** to commits, PRs, or code comments.
- **NEVER use `double()` in specs.** Real model instances or `Struct`.
- **NEVER hand-roll serialization on model classes.** No `def to_h` /
  `from_h` / `to_json` on `Entity`, `Klass`, etc. Service classes
  (`Cdd::Cddal::Serializer`, `Cdd::Exporters::Json`) are the correct
  pattern. Future lutaml-model migration tracked in plan 15.
- **`autoload`, never `require_relative`, inside `lib/`.** Define the
  autoload entries in the immediate parent namespace file.
- **Power-type faithful.** Instances-as-classes is the central abstraction,
  not an edge case. Every model decision must preserve it.
- **MECE entity types.** Adding a new entity type = adding a model class +
  reader, not editing a switch statement.
- **Persistence is downstream.** The in-memory model is canonical. Formats
  are views onto it.

## Milestones

| Milestone | Plans | Outcome |
|-----------|-------|---------|
| **M1 — Audit + correct** | 01, 02 | Spec suite green on existing fixtures; known registry discrepancies fixed. |
| **M2 — Parcel parity** | 03, 04, 05, 06 | Full ParcelMaker 5.2.1 read/write feature parity in the gem. |
| **M3 — CDDAL robust** | 07, 08, 10, 11, 12 | CDDAL round-trips through Parcel without semantic loss; validator passes R01–R15. |
| **M4 — CDDAL modules** | 09 | Split-file CDDAL with imports, cycle detection, URL fetcher. |
| **M5 — CDDAL spec** | 13, 14 | `cddal-spec` repo live, Metanorma-built, fed by the implementation. |

## Dependency graph

```
        01 ─┐
            ├─→ 02 ─┬─→ 03 ─┬─→ 05 ─┐
            │       │       │       ├─→ 06 ─┐
            │       │       └─→ 04 ─┘       │
            │       │                       │
            │       │   07 ─┬─→ 08 ─────────┼─→ 09
            │       │       │               │
            │       │       └─→ 10          │
            │       │                       │
            │       └───────────────────────┼─→ 12
            │                               │
            └───────────────────────────────┴─→ 13 ─→ 14
                                            
                                            15 (open questions, ongoing)
```

Read top-to-bottom. Plans at the same level can proceed in parallel once
their ancestors complete.

## Sequencing recommendation

1. Start with **plan 02** (audit + discrepancies) — it's the highest-value
   per hour because every downstream plan benefits from a correct registry.
2. Run **plan 12's** test matrix as a baseline *before* changes, so the
   effect of each plan is measurable.
3. Do **plans 03–06** in parallel once 02 lands — they're MECE.
4. **Plan 09** (CDDAL modules) is the biggest net-new feature; give it a
   dedicated branch and don't gate other work on it.
5. **Plan 13** (cddal-spec) can begin early but should land last, so the
   spec describes the implementation as shipped.

## Out of scope for this plan set

- The OpenCDD Editor (TS web app) — lives in `opencdd/editor/`, has its
  own roadmap.
- CDD upload to `cdd.iec.ch` — separate protocol investigation.
- CIM/RDF export — future; not in ParcelMaker 5.2.1.
- Live CDD search — blocked by AWS WAF on cdd.iec.ch.

These are tracked in plan 15 (open questions).

## Repo layout (target)

```
opencdd-ruby/
├── lib/
│   ├── cdd.rb                      # autoload root (Cdd module)
│   ├── opencdd.rb                  # gem entry (require "cdd")
│   └── cdd/
│       ├── entity.rb  klass.rb  property.rb  unit.rb
│       ├── value_list.rb  value_term.rb  relation.rb  view_control.rb
│       ├── database.rb
│       ├── irdi.rb  property_ids.rb  alias_table.rb  meta_class.rb
│       ├── class_type.rb  data_type.rb  value_format.rb  condition.rb
│       ├── property_data_element_type.rb  relation_type.rb  languages.rb
│       ├── effective_properties.rb
│       ├── class_tree.rb  composition_tree.rb  relation_tree.rb
│       ├── visitor.rb  validator.rb  validator/*.rb
│       ├── instance_rule.rb  guid.rb  structured_values.rb  parse_helpers.rb
│       ├── parcel.rb                # namespace + aggregate/split
│       │   └── parcel/*.rb
│       ├── cddal.rb                 # namespace + parse / serialize
│       │   └── cddal/*.rb           # lexer, parser, builder, serializer,
│       │                           #   modules (plan 09)
│       ├── exporters.rb             # namespace
│       │   └── exporters/*.rb       # json, yaml, mermaid
│       └── codegen/
│           └── ts.rb                # editor TS code generation
├── spec/                            # 41+ spec files
├── reference-docs/                  # source material — never delete
├── opencdd.gemspec
├── Rakefile
└── TODO.impl/                       # this directory
```

The `cddal-spec` repository (plan 13) is a **separate** repo at
`/Users/mulgogi/src/opencdd/cddal-spec/`.
