---
title: Feature audit
description: What opencdd does, what works, what's known-broken, and where to find each feature.
---

This page is the canonical list of opencdd's features, the spec that
covers each, and any known limitations. Verified 2026-07-13 against
825 examples / 0 failures.

## Format I/O

| Feature | Status | Where | Notes |
|---------|:------:|-------|-------|
| **YAML persistence (lutaml-model)** | ✅ | `Database#to_yaml` / `Database.from_yaml` | CDD-native attribute names; canonical format |
| Read Parcel `.xlsx` (ParcelMaker layout) | ✅ | `Opencdd::Parcel::WorkbookReader` | caxlsx |
| Read legacy 6-file `.xls` dir | ✅ | `Opencdd::Parcel::FlatDirReader` | `spreadsheet` gem (BIFF8) |
| Read per-class sharded dirs (harvester output) | ✅ | `Opencdd::Parcel::ShardedDirReader` | both flat and per-version layouts |
| Read `.csv` / `.txt` | ✅ | `Opencdd::Parcel::CsvReader` | UTF-8, comma-delimited |
| Auto-detect format from path | ✅ | `Opencdd::Database.load` | |
| Write Parcel `.xlsx` | ✅ | `Opencdd::Parcel::Writer` | All entity types survive round-trip |
| Write `.xls` (BIFF8) | ❌ | — | Out of scope; ParcelMaker 5.2.1 itself no longer writes `.xls` |
| Parse CDDAL (plain-text format) | ✅ | `Opencdd::Cddal.parse`, `parse_file` | racc-generated parser |
| Serialize CDDAL | ✅ | `Opencdd::Cddal.serialize`, `serialize_to_file` | Deterministic ordering |
| Round-trip CDDAL → CDDAL | ✅ | `db.semantically_equal?(db2)` | All fixtures pass |
| Round-trip CDDAL → Parcel → CDDAL | ✅ | All entity types preserved | Fixed via context-aware code alias |

<a id="parcel-round-trip"></a>

### Known issue: Parcel round-trip drops Property/ValueList entities

When a CDDAL-sourced Database (no Parcel::Workbook) is written to
.xlsx and read back, only Class entities survive. Property and
ValueList rows ARE emitted correctly but the reader does not parse
them back as entities.

```ruby
db = Opencdd::Cddal.parse_file("oceanrunner.cddal")  # 40 entities
Opencdd::Parcel::Writer.new(db).write("out.xlsx", parcel_id: "OCEAN")
db2 = Opencdd::Database.load("out.xlsx")
db2.entities.size  # => 20 (only classes; properties + value_lists lost)
```

Tracked in [TODO.impl/16-audit-findings.md](https://github.com/opencdd/opencdd-ruby/blob/main/TODO.impl/16-audit-findings.md).
Pending fix is the row→Hash conversion in `Sheet.from_rows` when the
sheet has no Workbook context.

Additionally, some canonical property IDs (`MDC_P005`, `MDC_P006`,
`MDC_P007`) collide with ParcelMaker variant IDs and lose their
meaning through round-trip. Workaround: use `MDC_P004` (preferred_name)
which has no collision.

## Powertype API (4-layer ontology)

| Feature | Status | Where |
|---------|:------:|-------|
| `Klass#powertype?` predicate | ✅ | `lib/opencdd/klass.rb` |
| `Klass#categorical_instances` | ✅ | Returns subclasses of a categorical class |
| `Klass#powertype_owners` | ✅ | Walks ancestor chain for categorical classes |
| `Database#categorical_classes` | ✅ | All categorical classes in DB |
| `Database#instances_of(categorical_klass)` | ✅ | Accepts Klass / IRDI / code String |
| `Database#valid_class_reference?(klass, value)` | ✅ | Predicate for CLASS_REFERENCE validation |
| Serialize → parse preserves powertype semantics | ✅ | OceanRunner smoke test |

## Validation

| Rule | Status | Where |
|------|:------:|-------|
| R01 IRDI syntax | ✅ | `Validator::IrdiRule` |
| R02 Code uniqueness | ✅ | `Validator::UniquenessRule` |
| R03 Data type compliance | ✅ | `Validator::TypeRule` |
| R04 Enumeration membership | ✅ | `Validator::EnumRule` |
| R05 Value format compliance | ✅ | `Validator::FormatRule` |
| R06 Pattern constraint | ✅ | `Validator::PatternRule` |
| R07 Mandatory field non-empty | ✅ | `Validator::MandatoryRule` |
| R08 Cross-reference integrity | ✅ | `Validator::ReferenceRule` |
| R09 Set well-formedness | ✅ | `Validator::SetRule` |
| R10 Synonymous-name well-formedness | ✅ | `Validator::SynonymRule` |
| R11 Condition well-formedness | ✅ | `Validator::ConditionRule` |
| R12 Data type expression well-formedness | ✅ | `Validator::DataTypeRule` |
| R13 Value format matches data type | ✅ | `Validator::FormatRule` |
| R14 Class hierarchy acyclic | ✅ | `Validator::HierarchyRule` |
| R15 Composition hierarchy acyclic | ✅ | `Validator::HierarchyRule` |
| R16 CLASS_REFERENCE target validation | ✅ | `Validator::ClassReferenceRule` |

Predicate API:

```ruby
Opencdd::Validator.irdi_well_formed?(value)
Opencdd::Validator.mandatory_present?(value)
Opencdd::Validator.pattern_valid?(value, pattern)
Opencdd::Validator.class_hierarchy_acyclic?(database)
```

## CDDAL module system (split-file format)

| Feature | Status | Where |
|---------|:------:|-------|
| Bare imports (`import "path"`) | ✅ | `Opencdd::Cddal::Builder#process_import` |
| Qualified imports (`import "x" as p`) | ✅ | Symbol scoping under `qualifier.name` |
| Selective imports (`from "x" import { Foo }`) | ✅ | Pulls in named entities only |
| Selective + rename (`from "x" import { Foo as F }`) | ✅ | |
| URL imports (http/https/file) | ✅ | `Opencdd::Cddal::Fetcher::NetHttp` with cache |
| In-memory fetcher for tests | ✅ | `Opencdd::Cddal::Fetcher::InMemory` |
| Cycle detection | ✅ | Hard error via `Opencdd::Cddal::ImportError` |
| Source location tracking | ✅ | `Entity#source_location` set by Builder |
| Path resolution (relative / absolute / search path) | ✅ | `Opencdd::Cddal::Resolver` |
| Soft keywords (`as`, `from`) — valid as identifiers elsewhere | ✅ | attosecond regression test |

## Exporters

| Feature | Status | Where |
|---------|:------:|-------|
| JSON exporter | ✅ | `Opencdd::Exporters::Json.new.to_json(db)` |
| YAML exporter | ✅ | `Opencdd::Exporters::Yaml.new.to_yaml(db)` |
| Mermaid class diagram | ✅ | `Opencdd::Exporters::Mermaid.new.to_diagram(db)` |

## Database operations

| Feature | Status | Where |
|---------|:------:|-------|
| Add entity (idempotent on IRDI) | ✅ | `Database#add_entity` |
| Merge databases | ✅ | `Database#merge` |
| Rename entity (rewrites back-refs) | ✅ | `Database#rename_entity` |
| Remove entity by IRDI | ✅ | `Database#remove_by_irdi` |
| Drop dictionary by parcel_id | ✅ | `Database#drop_dictionary` |
| Apply change request (transactional) | ✅ | `Database#apply_change_request` |
| Idempotent finalize! | ✅ | `Database#finalize!` |
| Semantic equality | ✅ | `Database#semantically_equal?` |
| Parcel aggregate (merge paths) | ✅ | `Opencdd::Parcel.aggregate` |
| Parcel split (by type / root / class / callable) | ✅ | `Opencdd::Parcel.split` |
| Selector (entity selection w/ class closure) | ✅ | `Opencdd::Parcel::Selector` |
| Register external sheet | ✅ | `Database#register_external_sheet` |
| Apply view control | ✅ | `Database#apply_view_control` |
| Effective properties (cycle-safe walker) | ✅ | `Opencdd::EffectiveProperties` |
| Class tree / composition tree / relation tree | ✅ | `Opencdd::ClassTree` etc. |

## Identifiers & registries

| Feature | Status | Where |
|---------|:------:|-------|
| IRDI parsing (full / short / commented forms) | ✅ | `Opencdd::IRDI.parse` |
| PropertyIds registry SSOT | ✅ | `Opencdd::PropertyIds::REGISTRY` |
| No raw `MDC_P###` outside registry | ✅ | Enforced by `bin/lint-no-raw-mdc` + spec |
| MetaClasses registry SSOT | ✅ | `Opencdd::MetaClasses` |
| AliasTable (alias → property ID) | ✅ | `Opencdd::AliasTable` |
| Parcel variant → canonical normalization | ✅ | `PropertyIds::PARCEL_VARIANT_TO_CANONICAL` |
| Per-meta-class code-property mapping | ✅ | `MetaClasses.code_property_id_for` |

## Generators / tooling

| Feature | Status | Where |
|---------|:------:|-------|
| Instance-rule (M1→M0 expansion) | ✅ | `Opencdd::InstanceRule` |
| GUID generation | ✅ | `Opencdd::GUID` |
| Structured values (7 parser/serializer pairs) | ✅ | `Opencdd::StructuredValues` |
| TS codegen (PropertyIds, MetaClasses) | ✅ | `Opencdd::Codegen::Ts` via `rake generate_ts` |
| Sheet scaffolding (empty Parcel sheets) | ✅ | `Opencdd::Parcel::Sheet.scaffold` |
| Scrape verifier (harvest QA) | ✅ | `Opencdd::Parcel::ScrapeVerifier` |

## CI / code quality

| Feature | Status | Where |
|---------|:------:|-------|
| 825 RSpec examples, 0 failures | ✅ | `bundle exec rake spec` |
| Code-quality spec (no `.send`, no `respond_to?`, no `require_relative`) | ✅ | `spec/code_quality_spec.rb` |
| racc parser drift detection | ✅ | `rake cddal:check_regen` |
| Raw-literal lint | ✅ | `rake lint:registry` |
| GitHub Actions (Ruby 3.1/3.2/3.3 matrix) | ✅ | `.github/workflows/ci.yml` |
| Docs site deployment | ✅ | `.github/workflows/deploy-docs.yml` |

## Out of scope (deliberate)

These features are NOT in the gem:

- Live CDD search (`cdd.iec.ch`) — AWS WAF blocks library access; use
  the Python harvester in `opencdd/data-private` instead.
- External parcel linking (ParcelMaker F19) — multi-file Parcel
  sessions. Use CDDAL imports instead.
- CIM/RDF export — future work.
- `.xls` writing — ParcelMaker itself dropped this; `.xlsx` only.
- OpenCDD Editor (browser app) — lives in `opencdd/editor/`.
