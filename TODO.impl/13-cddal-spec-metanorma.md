# Plan 13 — CDDAL specification in Metanorma (new cddal-spec repo)

## Why

The user's explicit requirement #5: author the CDDAL format specification
as a Metanorma document in a new `opencdd/cddal-spec` repository. The
existing draft at
`cdd-data/reference-docs/specs/cddal-v1.adoc` is a starting point; it
predates plan 09's module system, contains the property-ID
inconsistencies fixed in plan 02, and lives in the wrong repo (it's
currently inside the cdd-data reference materials, not its own
standards-track repo).

This plan delivers the new repo scaffold, the Metanorma document, and
the build pipeline that renders it to HTML / PDF / XML.

## Scope

- **New repository**: `/Users/mulgogi/src/opencdd/cddal-spec/`.
- Metanorma project layout (`metanorma.yml`, `sources/`, `Gemfile`).
- The CDDAL specification document (`sources/100/document.adoc` and
  its include files).
- Build pipeline (`rake build` → HTML / PDF in `published/`).
- GitHub Actions workflow to publish on push.
- Move (not copy) the draft content from
  `cdd-data/reference-docs/specs/cddal-v1.adoc`, with attribution and a
  pointer from the original location back to the canonical home.

Not in scope: the Ruby implementation (this whole plan set is the impl),
the IEC 61360 / 62656-1 standards (referenced, not reproduced).

## Approach

### Step 1 — Repo scaffold

At `/Users/mulgogi/src/opencdd/cddal-spec/`:

```
cddal-spec/
├── README.md                       # what this repo is
├── Gemfile                         # metanorma + ribose flavor
├── metanorma.yml                   # source list + collection metadata
├── Rakefile                        # build / clean / serve
├── .github/
│   └── workflows/
│       └── build.yml               # build + publish on push
├── sources/
│   └── 100/                        # document number 100 = CDDAL
│       ├── document.adoc           # entry — front matter + includes
│       ├── 01-scope.adoc
│       ├── 02-normative-references.adoc
│       ├── 03-terms-and-definitions.adoc
│       ├── 04-principles.adoc
│       ├── 05-architecture.adoc
│       ├── 06-lexical-structure.adoc
│       ├── 07-syntax.adoc
│       ├── 08-values-and-types.adoc
│       ├── 09-modules-and-imports.adoc       # plan 09's content
│       ├── 10-resolution-and-conformance.adoc
│       ├── 11-round-trip-stability.adoc
│       ├── A-builtin-aliases.adoc
│       ├── B-grammar-summary.adoc
│       └── C-examples/
│           ├── oceanrunner.adoc    # include oceanrunner.cddal
│           └── kagoshima.adoc
├── published/                      # gitignored build output
└── examples/
    ├── oceanrunner.cddal           # copied from opencdd-ruby reference-docs
    └── kagoshima.cddal
```

### Step 2 — metanorma.yml

Model on `/Users/mulgogi/src/mn/docs/metanorma.yml`:

```yaml
---
metanorma:
  source:
    files:
      - sources/100/document.adoc

  collection:
    organization: "OpenCDD"
    name: "OpenCDD specifications"
```

### Step 3 — Gemfile

```ruby
source "https://rubygems.org"
gem "metanorma-ribose", "~> 2.0"
gem "rake", "~> 13.0"
```

### Step 4 — Document entry (sources/100/document.adoc)

Front matter matches the mn/docs convention (see
`mn/docs/sources/109/document.adoc`):

```asciidoc
= OpenCDD 1: CDD Authoring Language (CDDAL) specification
:docnumber: 1
:edition: 1
:revdate: 2026-07-11
:copyright-year: 2026
:language: en
:title-main-en: CDD Authoring Language (CDDAL) specification
:doctype: standard
:status: draft
:mn-document-class: ribose
:mn-output-extensions: xml,html,pdf,rxl
:local-cache-only:

[abstract]
...

include::01-scope.adoc[]
include::02-normative-references.adoc[]
include::03-terms-and-definitions.adoc[]
include::04-principles.adoc[]
include::05-architecture.adoc[]
include::06-lexical-structure.adoc[]
include::07-syntax.adoc[]
include::08-values-and-types.adoc[]
include::09-modules-and-imports.adoc[]
include::10-resolution-and-conformance.adoc[]
include::11-round-trip-stability.adoc[]

[appendix]
include::A-builtin-aliases.adoc[]
[appendix]
include::B-grammar-summary.adoc[]
[appendix]
include::C-examples/oceanrunner.adoc[]
[appendix]
include::C-examples/kagoshima.adoc[]
```

### Step 5 — Section content

Migrate and expand the existing draft. Each section's content:

- **01 Scope** — from current §"Scope". States CDDAL is a peer of Parcel,
  not a replacement; information-equivalent.
- **02 Normative references** — IEC 61360-1, IEC 61360-2, IEC 62656-1,
  ISO/IEC 11179-6, RFC 5646 (language tags), RFC 3986 (URIs), ISO 8601
  (dates).
- **03 Terms and definitions** — meta-class, instance, IRDI, property
  identifier, alias, declaration, assignment, value, block, module,
  import, qualifier, selector.
- **04 Principles** — Power-type faithful, Human-readable, Round-trip
  stable, Parcel-equivalent, Implementation-free, Internationalization,
  Extensible, Single source of truth.
- **05 Architecture** — three model trees (meta-class, instance,
  property graph); runtime responsibilities.
- **06 Lexical structure** — whitespace, comments, identifiers, IRDIs,
  string/number/date/boolean literals, keywords (incl. new `as`, `from`).
- **07 Syntax** — EBNF for `document`, `declaration`, `meta_class_decl`,
  `instance_decl`, `alias_decl`, `import_decl` (extended by §09),
  `assignment`, `value`.
- **08 Values and types** — Literal kinds, IdentifierRef, Set, Tuple,
  ClassReference (`CLASS_REFERENCE(...)`, `ENUM_*_TYPE(...)`), Condition.
- **09 Modules and imports** — **NEW** from plan 09. Bare, qualified
  (`as`), selective (`from … import { … }`) forms; path/URL resolution;
  cycle detection; source location tracking; scoping rules.
- **10 Resolution and conformance** — symbol table, resolution order
  (full IRDI → symbolic → code), conformance classes (parser / serializer
  / runtime), error conditions.
- **11 Round-trip stability** — required invariants; semantic equality;
  deterministic ordering guidance for serializers.
- **Appendix A — Built-in aliases** — table from
  `cddal-v1.adoc` appendix, with plan 02's fixes applied.
- **Appendix B — Grammar summary** — single-page EBNF.
- **Appendix C — Worked examples** — OceanRunner (full file included),
  Kagoshima (full file included).

### Step 6 — Reconciliation with implementation

Each section that names a property ID (MDC_P### / MDC_C###) cross-checks
against `lib/cdd/property_ids.rb` and `lib/cdd/meta_class.rb` in the
opencdd-ruby repo. The Ruby REGISTRY is the SSOT.

A CI check in opencdd-ruby (plan 14) runs a script that extracts every
`MDC_[CP]###` literal from `cddal-spec/sources/` and asserts they're
present in `Cdd::PropertyIds::REGISTRY` / `Cdd::MetaClasses::REGISTRY`.

### Step 7 — Build pipeline

`cddal-spec/Rakefile`:

```ruby
task :build => %i[html pdf xml]
task :html do
  sh "bundle exec metanorma -t html sources/100/document.adoc"
end
task :pdf do
  sh "bundle exec metanorma -t pdf sources/100/document.adoc"
end
task :xml do
  sh "bundle exec metanorma -t xml sources/100/document.adoc"
end
task :clean do
  rm_rf "published"
end
```

### Step 8 — Move the draft

In `cdd-data/reference-docs/specs/cddal-v1.adoc`, replace the file
content with a one-line pointer:

```
// Moved to https://github.com/opencdd/cddal-spec — see sources/100/document.adoc.
// This file is retained as a redirect for old links.
```

Do **not** delete the original file (per global CLAUDE.md: never delete
source). The redirect-and-pointer approach preserves the provenance
trail.

### Step 9 — GitHub Pages / release

The `cddal-spec` repo's `published/` output is committed on release
tags (or published via GitHub Pages). The README links to the latest
rendered HTML.

## Acceptance criteria

- [x] `opencdd/cddal-spec` repo exists at
      `/Users/mulgogi/src/opencdd/cddal-spec/`.
- [x] `bundle exec metanorma sources/100/document.adoc` produces HTML,
      PDF, and XML without warnings.
- [x] Document covers every section listed in step 5.
- [x] Plan 09's module system fully specified (§09) with examples.
- [x] All `MDC_P###` / `MDC_C###` literals in the spec are present in
      the Ruby REGISTRY (CI check).
- [x] Plan 02's ID fixes reflected in appendix A.
- [x] Original draft at `cdd-data/reference-docs/specs/cddal-v1.adoc`
      replaced with a redirect pointer (file not deleted).
- [x] README in the new repo explains what the spec is, how to build
      it, and how to file issues.

## Dependencies

- **Plan 02** — ID fixes.
- **Plan 09** — module system spec content.
- **Plan 07** — grammar (spec describes the grammar implemented).
- **Plan 14** — CI cross-check script.

## Open questions

- **Q1. Document number.** mn/docs uses 109/110/111/.../115 for the
  Metanorma-internal series. For OpenCDD, what numbering? Recommendation:
  `1` for the CDDAL spec (docnumber: 1), reserving 2+ for future
  OpenCDD specs (e.g., parcel-format, opencdd-editor).
- **Q2. License.** CC-BY-SA for the spec text? Recommendation: yes;
  the spec describes an open format.
- **Q3. Should the spec be submitted to ISO/IEC JWG 24 eventually?
  Recommendation:** out of scope for now; ship as an OpenCDD community
  spec first. Standardization is a separate decision.
- **Q4. Translations.** Should the spec itself be translated (fr/ja)?
  Recommendation:** no for v1 — English only; non-normative translations
  can be community-contributed.
