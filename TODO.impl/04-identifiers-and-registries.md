# Plan 04 — Identifiers and registries

## Why

Every entity in CDD is identified by an IRDI; every property of every
meta-class has a stable property ID. The Ruby gem's `PropertyIds`,
`MetaClasses`, and `AliasTable` registries are the single source of truth
(SSOT) — no raw `"MDC_P###"` / `"MDC_C###"` literal is allowed outside
these files (per plan 01).

This plan locks down the SSOT, ensures it matches IEC 62656-1 / IEC 61360-1
/ the ParcelMaker VBA constants, and ensures every consumer reads from it.

## Scope

- `Cdd::IRDI` — parsing, equality, canonicalization.
- `Cdd::PropertyIds` — registry of every property ID + reverse aliases.
- `Cdd::MetaClasses` — registry of every meta-class IRDI.
- `Cdd::AliasTable` — alias → property ID resolution, built-in defaults.
- Variant normalization (`MDC_P004_1` → `MDC_P004`).
- Code generation for the TS editor port.

Not in scope: model classes that consume the registry (plan 03), Database
(plan 05).

## Approach

### IRDI (lib/cdd/irdi.rb)

Supports the three forms from `04_validation_rules.md` R01:

| Form      | Example                              |
|-----------|--------------------------------------|
| Full      | `0112/2///62656_1#AAA001##1`         |
| Short     | `AAA001` or `MDC_C002`               |
| Commented | `0112/2///62656_1#AAA001##1###note`  |

Public API:

```ruby
Cdd::IRDI.parse(string)           # → Cdd::IRDI or raises Cdd::IRDI::ParseError
Cdd::IRDI.well_formed?(string)    # → bool
irdi.full_form                    # → "0112/2///62656_1#AAA001##1"
irdi.short_form                   # → "AAA001"
irdi.code                         # → "AAA001"
irdi.supplier                     # → "0112/2///62656_1" or nil
irdi.version                      # → Integer or nil
irdi.comment                      # → String or nil
irdi.to_s                         # → original form
irdi.eql?(other) / hash           # value-equality ignoring comment
```

Equality semantics: two IRDIs are equal if they resolve to the same entity
(supplier + code + version). Comment is metadata, not identity.

Helpers (already present, keep them):

```ruby
Cdd::PropertyIds.as_entity_irdi(code, meta_class_irdi:, supplier:, version:)
Cdd::PropertyIds.as_property_irdi(...)
```

### PropertyIds (lib/cdd/property_ids.rb)

`REGISTRY` is a `Hash{ String => Entry }` keyed by property ID. `Entry`
has at minimum:

- `id` — the canonical ID (`"MDC_P022"`).
- `aliases` — array of symbolic names (`["data_type", "datatype"]`).
- `applies_to` — array of meta-class IDs that declare it.
- `value_kind` — `:scalar` / `:identifier_ref` / `:set_of_refs` /
  `:class_ref` / `:structured` / `:localized_string`.
- `parcel_variant` — original ParcelMaker variant ID if different from
  canonical (e.g. `MDC_P005` → variant `MDC_P005`).

For every key in `REGISTRY`, a matching constant is defined:

```ruby
module Cdd::PropertyIds
  REGISTRY.each do |id, _entry|
    const_set(id, id)
  end
end
```

So callers write `Cdd::PropertyIds::MDC_P022`, never `"MDC_P022"`.

`PARCEL_VARIANT_TO_CANONICAL` maps ParcelMaker variant IDs to canonical
IDs (`MDC_P005` → `MDC_P005`, `MDC_P004_2` → `MDC_P007`, etc.). The
Parcel reader applies this map when populating `Entity#properties`.

`CODE_PROPERTY_BY_META_CLASS` maps a meta-class IRDI to the property ID
that holds its code (e.g. `MDC_C002` → `MDC_P001_5`). Used by
`Entity#code`.

### MetaClasses (lib/cdd/meta_class.rb)

`REGISTRY` is a `Hash{ String => Entry }` keyed by meta-class ID. Entry:

- `id` — `"MDC_C002"`.
- `name` — `"Class"`.
- `type` — `:class` (Symbol used throughout the codebase).
- `sheet_type` — `"CLASS"` (Parcel sheet-type string).
- `code_property_id` — `MDC_P001_5`.

The fix from plan 02 lands here: `MDC_C011` is Relation, `MDC_C006` is
Datatype.

Derived maps (computed once at load):

```ruby
MetaClasses::TYPE_BY_META_CLASS   # { "MDC_C002" => :class, ... }
MetaClasses::META_CLASS_BY_TYPE   # inverse
MetaClasses::SHEET_TYPE_BY_META_CLASS
```

### AliasTable (lib/cdd/alias_table.rb)

Public API:

```ruby
table = Cdd::AliasTable.new(database:)    # inherits database's overrides
table.resolve("superclass")               # → "MDC_P010"
table.resolve("MDC_P010")                 # → "MDC_P010" (passthrough)
table.declare("colour", "MDC_P999")       # adds a document-scoped alias
table.each_alias                          # enumerable
```

Built-in defaults: see the appendix of `cddal-v1.adoc` (after plan 02's
fixes). The AliasTable seeds from these defaults, then layers document
overrides from `alias` declarations in CDDAL or header rows in Parcel.

Collision policy: if a document declares an alias that already exists,
emit a warning and overwrite. The cdd-data spec `00_overview.md` notes
the SSOT principle — one alias per ID per document.

### Code generation (lib/cdd/codegen/ts.rb)

`rake generate_ts` reads the Ruby `REGISTRY` and emits two checked-in TS
files for the editor:

- `editor/src/models/PropertyIds.generated.ts`
- `editor/src/models/MetaClasses.generated.ts`

The Ruby REGISTRY is the source; TS is the derived output. Never edit the
`.generated.ts` files by hand.

### No raw literals rule

After this plan:

```bash
grep -rn '"MDC_[CP]0[0-9]' lib/cdd/ \
  | grep -v 'lib/cdd/property_ids.rb' \
  | grep -v 'lib/cdd/meta_class.rb' \
  | grep -v 'lib/cdd/alias_table.rb'
# expected: empty
```

Same for `"EXT_P###"`, `"EXT_C###"`, `"CIM_P###"`.

## Acceptance criteria

- [ ] `Cdd::IRDI.parse` accepts all three forms; `well_formed?` matches.
- [ ] `Cdd::PropertyIds::REGISTRY` covers every ID in
      `cdd-data/specs/parcelmaker/03_property_registry.md`.
- [ ] Every `REGISTRY` key has a matching constant
      (`Cdd::PropertyIds::MDC_P022 == "MDC_P022"`).
- [ ] `Cdd::MetaClasses::REGISTRY` has `MDC_C011` for Relation and
      `MDC_C006` for Datatype.
- [ ] No raw `"MDC_P###"` / `"MDC_C###"` literal outside the three
      registry files.
- [ ] `rake generate_ts` regenerates the editor's `.generated.ts` files
      idempotently.
- [ ] `spec/irdi_spec.rb`, `spec/property_ids_spec.rb`,
      `spec/meta_class_spec.rb`, `spec/alias_table_spec.rb` green.

## Dependencies

- **Plan 01** — conventions.
- **Plan 02** — fixes land here (registry is the destination for the
  corrected IDs).

## Open questions

- **Q1.** Should the AliasTable warn or error on collision? Currently
  warns. **Recommendation:** warn by default, strict mode in validator.
- **Q2.** Do we need versioned aliases (e.g., `superclass` resolving
  differently in IEC 61360-4 vs IEC 61360-5)? **Recommendation:** no —
  aliases are document-scoped, not version-scoped. Documents pin their
  own overrides via `alias` declarations.
