# Plan 02 — Audit current state and fix property-registry discrepancies

## Why

The cdd-data spec at `specs/parcelmaker/03_property_registry.md` enumerates
concrete bugs in the current `lib/cdd/` extraction where property IDs and
meta-class IRDIs are wrong relative to the ParcelMaker VBA source (which
itself reflects IEC 62656-1). Every downstream plan inherits these bugs
unless they're fixed first.

This plan is the highest-leverage work in the set: small, mechanical, and
unblocks correctness everywhere else.

## Scope

1. **Run the existing spec suite** and capture a baseline pass/fail.
2. **Reconcile every discrepancy** enumerated in
   `cdd-data/specs/parcelmaker/03_property_registry.md`
   §"Discrepancy with current Ruby code".
3. **Reconcile CDDAL-spec inconsistencies** — the draft at
   `cdd-data/reference-docs/specs/cddal-v1.adoc` cites wrong IDs for
   `imported_properties` and `sub_class_selection`. Update the spec
   draft in-place (the canonical move to cddal-spec happens in plan 13).
4. **Run the spec suite again** and ensure no regressions.
5. Commit per-discrepancy so reverts are surgical.

## Approach

### Step 1 — Baseline

```bash
cd /Users/mulgogi/src/opencdd/opencdd-ruby
bundle install
bundle exec rspec --format documentation 2>&1 | tee /tmp/cdd-baseline.log
```

Capture: total examples, failures, pending. This is the **before** state.
Plan 12 will turn this into a structured test matrix.

### Step 2 — Discrepancies from `03_property_registry.md`

These are enumerated in the cdd-data spec. Reproduced here for actionability
— the cdd-data spec is the source of truth.

#### 2a. Meta-class IDs (lib/cdd/meta_class.rb)

| Meta-class | Currently | Correct | Note |
|------------|-----------|---------|------|
| Datatype   | —         | `MDC_C006` | Currently absent; added. |
| Relation   | `MDC_C006` | `MDC_C011` | Wrong ID in current code. |

Action: in `lib/cdd/meta_class.rb`, reassign `MDC_C006 → Datatype`,
add `MDC_C011 → Relation`. Update `TYPE_BY_META_CLASS` and
`META_CLASS_BY_TYPE` accordingly. Search for any code that hard-codes
`MDC_C006` meaning Relation and fix it.

#### 2b. Property reads (lib/cdd/property.rb)

| Ruby method                | Reads today        | Should read        |
|----------------------------|--------------------|--------------------|
| `data_type`                | `MDC_P018`         | `MDC_P022`         |
| `value_format`             | `MDC_P022`         | `MDC_P024`         |
| `definition_class_irdi`    | `MDC_P017`         | `MDC_P021`         |
| `unit_irdi`                | `MDC_P030`         | `MDC_P041`         |
| `alternative_unit_irdis`   | `MDC_P031`         | `MDC_P042`/`MDC_P111` |
| `formula`                  | `MDC_P026_1`/`MDC_P026` | `MDC_P027_1`/`MDC_P027_2` |
| `symbol_in_text`           | `MDC_P023_1`/`MDC_P021` | `MDC_P025_1`   |
| `constraint`               | `MDC_P032`         | `MDC_P068`         |

Action: edit each method's `properties[Cdd::PropertyIds::<CONST>]` lookup
to the corrected constant. Add a regression spec per method.

#### 2c. Property reads (lib/cdd/klass.rb)

| Ruby method                    | Reads today | Should read |
|--------------------------------|-------------|-------------|
| `imported_property_irdis`      | `MDC_P040`  | `MDC_P090`  |
| `sub_class_selection_irdis`    | `MDC_P033`  | `MDC_P016`  |

#### 2d. Extend REGISTRY (lib/cdd/property_ids.rb)

Add `Entry` records for each missing ID with VBA-constant alias and
applies-to metadata. Missing IDs from the cdd-data spec:

- **Class-level**: `MDC_P012`, `MDC_P014_1`, `MDC_P014_2`, `MDC_P015`,
  `MDC_P015_1`, `MDC_P015_2`, `MDC_P016`, `MDC_P090`, `MDC_P091`,
  `MDC_P093`, `MDC_P094`, `MDC_P094_1`, `MDC_P094_2`.
- **Property-level**: `MDC_P024`, `MDC_P025_1`, `MDC_P025_2`,
  `MDC_P025_3`, `MDC_P027_1`, `MDC_P027_2`, `MDC_P041`, `MDC_P042`,
  `MDC_P068`, `MDC_P096`, `MDC_P097`, `MDC_P101`, `MDC_P102`,
  `MDC_P110`, `MDC_P111`, `MDC_P114`.
- **Relation-level**: `MDC_P230`, `MDC_P231`.
- **CIM extension**: `CIM_P001`–`CIM_P005`.
- **Codes for completeness**: `MDC_P001_1`, `MDC_P001_2`, `MDC_P001_7`,
  `MDC_P001_8`.

#### 2e. Reassign aliases (lib/cdd/alias_table.rb built-ins)

| Alias                       | Currently on  | Should be on  |
|-----------------------------|---------------|---------------|
| `data_type`                 | `MDC_P018`    | `MDC_P022`    |
| `value_format`              | `MDC_P022`    | `MDC_P024`    |
| `definition_class`          | `MDC_P017`    | `MDC_P021`    |
| `unit` / `unit_irdi`        | `MDC_P030`    | `MDC_P041`    |
| `alternative_units`         | `MDC_P031`    | `MDC_P042`    |
| `constraint`                | `MDC_P032`    | `MDC_P068`    |
| `sub_class_selection`       | `MDC_P033`    | `MDC_P016`    |
| `imported_properties`       | `MDC_P040`    | `MDC_P090`    |
| `symbol` (Property)         | `MDC_P021`    | `MDC_P025_1`  |
| `property_formula`          | `MDC_P026`    | `MDC_P027_1`  |
| `property_formula_localized`| `MDC_P026_1`  | `MDC_P027_2`  |

The displaced IDs keep their REGISTRY entries with their VBA-constant
aliases (`coded_name`, `class_value_assignment`, etc.) — Parcel xlsx
files in the wild may still reference them.

#### 2f. Update tests that encode the bug

`spec/property_ids_spec.rb`, `spec/alias_table_spec.rb`,
`spec/property_spec.rb`, `spec/klass_spec.rb`,
`spec/meta_class_spec.rb`, and any other spec asserting the old wrong
values. Update assertions to the corrected values.

#### 2g. CDDAL spec draft inconsistencies

In `cdd-data/reference-docs/specs/cddal-v1.adoc`:

- §"AliasDecl" example: `alias imported_properties: MDC_P040` → `MDC_P090`.
- §"AliasDecl" example: `alias sub_class_selection: MDC_P033` → `MDC_P016`.
- §"Built-in property aliases" appendix: same two rows.
- §"meta-class" terms-and-definitions: Relation meta-class is `MDC_C011`,
  not `MDC_C006`. Datatype is `MDC_C006`.

### Step 3 — Verification

```bash
bundle exec rspec
bundle exec rake build    # gem must still build
```

Run the OceanRunner CDDAL round-trip spec (`spec/cddal_spec.rb`) — it must
remain semantically equal. Same for any `spec/parcel/round_trip_spec.rb`.

### Step 4 — Commit strategy

One commit per discrepancy class, on a feature branch, one PR per commit:

1. `branch: fix/meta-class-irdi-relation` — step 2a.
2. `branch: fix/property-reads-correct-ids` — steps 2b + 2c.
3. `branch: fix/registry-add-missing-ids` — step 2d.
4. `branch: fix/alias-reassignment` — step 2e + 2f (together, since
   tests assert alias→ID).
5. `branch: docs/cddal-spec-id-fixes` — step 2g.

Never commit to main. Never push tags. No AI attribution in any commit.

## Acceptance criteria

- [x] Baseline spec output captured at `/tmp/cdd-baseline.log`.
- [x] All discrepancies from `03_property_registry.md` fixed.
- [x] `bundle exec rspec` green (or, if any pre-existing failures remain,
      their count is unchanged and they are documented in plan 12).
- [x] OceanRunner CDDAL round-trip still semantically equal.
- [x] `lib/cdd/property_ids.rb` REGISTRY contains every ID cited in
      `03_property_registry.md`.
- [x] No raw `"MDC_P022"` / `"MDC_P090"` / etc. literal in `lib/cdd/`
      outside `property_ids.rb` and `meta_class.rb`.
- [x] CDDAL spec draft at `cdd-data/reference-docs/specs/cddal-v1.adoc`
      uses the corrected IDs in examples and appendices.

## Dependencies

- **Plan 01** — conventions (no `require_relative`, no AI attribution, etc.).

## Open questions

- **Q1.** If a fixture (e.g., theParcelMaker nuts xlsx) encodes a value
  under a wrong ID, do we re-key on import or preserve verbatim?
  **Recommendation:** preserve verbatim in `Entity#properties`, re-key
  in the typed accessor. That way the reader is lossless and the typed
  API is correct.
