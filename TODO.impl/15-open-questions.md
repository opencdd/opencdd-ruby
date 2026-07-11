# Plan 15 — Open questions and future work

## Why

Not every decision is settled by plans 01–14. This file collects the
explicitly-deferred questions, the future-work items out of scope for
v1, and the audit findings from the project CLAUDE.md that need a home
in this plan set. Surfacing them here prevents them from being forgotten
or silently re-decided.

Each item has an owner-type (decision / future work / external) and an
estimated size.

## Open decisions (need user input before implementation)

### D1 — lutaml-model migration scope and timing

The global CLAUDE.md mandates "NEVER hand-roll serialization — use
lutaml-model only". The current `Entity` / `Klass` / `Property` classes
use plain `Hash` for `properties` and hand-rolled accessors. They don't
hand-roll `to_h` (good), but they also don't use `lutaml-model` typed
attributes (debt per the rule).

The project CLAUDE.md tracks this as "Phase 2 NOT started".

**Decision needed:** when does this migration happen, and what does the
post-migration model look like?

Options:
- **A. Migrate now** (before plan 03 lands). Cleanest; biggest blast
  radius.
- **B. Migrate after plans 02–12 land.** Pragmatic; the current model
  works, just not idiomatic.
- **C. Don't migrate; document an exception.** The rule was written for
  Coradoc; CDD's `properties` Hash is closer to a property-bag pattern
  than a typed model.

**Recommendation:** B, with a follow-up TODO.impl plan (16) drafted
once the format work stabilizes.

Owner-type: decision. Size: L.

### D2 — Multilingual field shape (nested vs flat)

Two valid representations for translatable strings:

- **Nested:** `{ "en" => "Vehicle", "fr" => "Véhicule" }` (Ruby Hash).
- **Flat:** one row per language in Parcel; one assignment per language
  in CDDAL (`prop.en: ...`, `prop.fr: ...`).

Current code uses **nested in Ruby, flat in formats**. The serializer
(plan 08) translates.

**Decision needed:** confirm this is the canonical split, or unify.
The Cdd::Languages value object (plan 03) is the boundary.

**Recommendation:** keep the current split; document it in plan 03.

Owner-type: decision. Size: S.

### D3 — URL fetcher policy in CI

Tests for plan 09's URL imports need a fetcher. CI must not hit the
network (flaky, slow).

**Decision:** use `Cdd::Cddal::Fetcher::InMemory` for all tests that
exercise URLs; mark any spec that needs real network as `pending:
"requires network"` and skip on CI.

Owner-type: decision. Size: S.

### D4 — File format default for per-entity persistence (future)

If/when the project adds per-entity YAML/JSON file layout (referenced in
project CLAUDE.md Phase 2), what's the default?

**Decision:** not in scope for v1. Defer to plan 16 (lutaml-model).

Owner-type: decision. Size: M.

### D5 — CIM/RDF export

IEC 61360 / 62656-1 mention CIM/RDF as export targets. The cdd-data
spec marks CIM/RDF as future.

**Decision:** not in scope for this plan set. Track as future work.

Owner-type: decision. Size: L.

### D6 — CDD upload protocol investigation

The cdd-data spec's roadmap has Phase 2 = CDD upload investigation.
The OpenCDD Editor (separate repo) is the consumer.

**Decision:** out of scope for the Ruby gem. Track in the editor repo.

Owner-type: external. Size: M.

## Audit findings from project CLAUDE.md (2026-06-25)

The project CLAUDE.md's audit section enumerates findings A1–A4. They
need a home in this plan set:

### A1 — Condition grammar rejects class-reference sets

Current `Cdd::Condition` only accepts equality against literals or
single-value sets. Class-reference sets (used in some ParcelMaker
fixtures) aren't accepted.

**Home:** plan 03 (Condition value object) + plan 07 (grammar).
Interim workaround in `Property#condition` per CLAUDE.md. Permanent fix
is extending the condition grammar.

Size: M.

### A2 — Dead `format_set` in CDDAL serializer

`Cdd::Cddal::Serializer` has an unused `format_set` method.

**Home:** plan 08. Delete during serializer cleanup.

Size: S.

### A3 — Parcel writer normalizes `"001" → "1"`

`Cdd::Parcel::Writer` coerces string codes that look like integers to
actual integers, dropping leading zeros. Real codes (e.g. `"0112"`)
must round-trip verbatim.

**Home:** plan 06. Pin the writer to preserve string codes.

Size: S.

### A4 — entity.rb vs REGISTRY property ID discrepancies

Already covered by plan 02 (which is the comprehensive fix). Mark A4
closed when plan 02 lands.

Size: M.

## Future work (explicitly deferred)

### F1 — Per-entity YAML/JSON file layout

Per project CLAUDE.md Phase 2. Each entity lives in its own file under
`data/<type>/<code>.yml`. Allows git-friendly incremental edits.
Depends on D1 (lutaml-model).

### F2 — Snapshot of public CDD dictionaries as CDDAL

Host `iec61360-7.cddal`, `iec62683.cddal`, etc. on opencdd.github.io.
Removes dependency on cdd.iec.ch for cross-dictionary references.
Depends on plan 09 (URL imports).

### F3 — Selector / partition / split CLI

`opencdd split --by each_class --input path.xlsx --output-dir out/` —
command-line interface to `Cdd::Parcel.split`. Useful for packaging
dictionary subsets.

### F4 — Selective export with dependency lifting

When exporting a single class, automatically lift its declared
properties, their value lists, and their units. Already partially done
in `Cdd::Parcel.split(by: :each_class, lift_dependencies: true)` —
expose as a top-level CLI / API.

### F5 — Versioned modules and integrity pins

Plan 09's open questions Q1 and Q2 — `import "url" version "1.2"` and
`sha256 "..."` pins. Defer until a consumer needs reproducibility.

### F6 — Visibility modifiers (`pub`/`priv`)

Plan 09's open question Q3. Adds Rust-style visibility to declarations.
Defer; selective imports cover most use cases.

### F7 — Streaming JSON exporter

For >100k-entity databases. Plan 11's Q1.

### F8 — Verbose Mermaid exporter

Property values in the diagram. Plan 11's Q2.

### F9 — Multi-document workspaces (`cddal.toml`)

Plan 09's Q5. Workspace manifest declaring module roots and search
paths.

### F10 — `opencdd` CLI gem

A separate `opencdd-cli` gem that wraps the library with a Thor-based
CLI: `opencdd validate path.xlsx`, `opencdd convert from.xlsx to.cddal`,
etc. Out of scope for the library gem itself.

## Cross-repo dependencies

| Repo | Relationship |
|------|--------------|
| `opencdd/opencdd-ruby` (this repo) | The gem. |
| `opencdd/cdd-data` | Source-of-truth reference docs + ParcelMaker spec + fixtures. Referenced from spec_helper. |
| `opencdd/editor` | TypeScript port; consumes generated TS from `rake generate_ts`. |
| `opencdd/cdd-models-ts` | Shared TS model types between editor and browser. |
| `opencdd/cddal-spec` | New repo from plan 13. |
| `opencdd/opencdd.github.io` | Static site hosting published dictionaries + spec HTML. |

The Ruby gem is the SSOT for:
- Property ID registry (`Cdd::PropertyIds::REGISTRY`).
- Meta-class registry (`Cdd::MetaClasses::REGISTRY`).
- Alias defaults.
- CDDAL grammar (`cddal.y`).
- Round-trip semantics.

Everything downstream (TS port, spec doc, editor) reads from this repo.

## When this plan changes

Update this file when:
- A decision in §"Open decisions" is resolved (move the resolution
  inline; don't delete the question).
- A future-work item gets scheduled into a numbered plan (move it; add
  a pointer).
- A new audit finding is filed.

This plan is a living document; it should never be "done."
