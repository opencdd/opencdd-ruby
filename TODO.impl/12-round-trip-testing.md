# Plan 12 — Round-trip testing strategy and golden fixtures

## Why

A CDD library's defining quality is **round-trip stability**: read a
file, write it back, read the result, and the two in-memory Databases
are semantically equal. Without an explicit, structured test matrix,
regressions hide.

This plan defines the test matrix, the golden fixtures, the semantic
equality predicate, and the regression snapshot pattern. It depends on
all format plans (06, 07, 08, 09, 11) and on plan 02's discrepancy
fixes.

## Scope

- The `semantically_equal?` predicate (already on Database).
- The fixture corpus and what each fixture exercises.
- The round-trip test matrix (10+ test combinations).
- Snapshot testing for serializer output.
- Property-registry invariant specs.
- Performance regression baseline (informational).

Not in scope: new format support (other plans), validation rules
(plan 10).

## Approach

### Semantic equality

`db1.semantically_equal?(db2)` is the single equivalence predicate used
throughout. Defined in plan 05. Rules:

- Same set of entity IRDIs.
- For each IRDI: same meta-class, same code, same raw `properties`
  (after canonicalizing set ordering and trimming whitespace).
- Declaration order insignificant.
- Source location insignificant (a CDDAL entity and a Parcel entity
  with the same data are equal).

### Fixture corpus

Lives under `reference-docs/` and `spec/fixtures/`. Never delete
(plan 01).

| Fixture | Location | What it exercises |
|---------|----------|-------------------|
| **OceanRunner** | `reference-docs/examples/oceanrunner.cddal` | Multilingual, is_case_of, CONDITION_DET, categorical classes, CLASS_REFERENCE, sub_class_selection, individual unit instance. HTTPS import (skipped). |
| **Kagoshima IEC def** | `reference-docs/202003-kagoshima-iec-def-sample.cddal` | Bare `instance` form (no `<` syntax), `property-meta-class` / `enumeration-meta-class` / `term-meta-class` declarations (pre-standard-naming), parenthesized value lists `(a,b)` vs brace form `{a,b}`. |
| **ParcelMaker nuts** | `reference-docs/parcelmaker/(ParcelMaker)example_nut.xlsx` | Canonical small Parcel workbook; multilingual; value lists; relations. |
| **IEC62683 xlsx** | `reference-docs/export_CDD_IEC62683 in ParcelMaker format.xlsx` | Real-world dictionary; reserved sheets (`Project`, `sheetmap`, `pcls_LOCAL`); all 10 sheet types. |
| **IEC62368 legacy .xls** | `reference-docs/export_CDD_IEC62368 in EXCEL format/` | Flat 6-file BIFF8 layout. |
| **IEC ICS legacy single .xls** | `reference-docs/export_CDD_ISO ICS in EXCEL format.xls` | Single-file legacy. |
| **Synthetic fixtures** | `spec/fixtures/*.cddal` | Edge cases: empty db, single-class, cycle (negative test), large set, all data types. |

### Round-trip test matrix

`spec/round_trip_spec.rb` (and per-format files) — every cell in the
matrix is one spec:

| From → To | OceanRunner | Kagoshima | Nuts xlsx | IEC62683 | IEC62368 |
|-----------|:-----------:|:---------:|:---------:|:--------:|:--------:|
| CDDAL → CDDAL | ✅ | ✅ | n/a | n/a | n/a |
| CDDAL → Parcel | ✅ | ✅ | n/a | n/a | n/a |
| Parcel → CDDAL | n/a | n/a | ✅ | ✅ | n/a |
| Parcel → Parcel | n/a | n/a | ✅ | ✅ | ✅ (read-only) |
| CDDAL → JSON → CDDAL | ✅ | ✅ | ✅ | ✅ | ✅ |
| CDDAL → YAML → CDDAL | ✅ | ✅ | ✅ | ✅ | ✅ |

✅ = expected to pass; n/a = format doesn't apply.

Each cell:
1. Read source into `db1`.
2. Serialize to target format.
3. Read serialized output into `db2`.
4. Assert `db1.semantically_equal?(db2)`.

For the Parcel → Parcel cells on legacy `.xls`, write isn't supported
(plan 06 Q3) — that cell is read-only.

### Serializer determinism specs

For each (format, fixture) pair:

```ruby
it "is deterministic across runs" do
  out1 = Cdd::Cddal.serialize(db)
  out2 = Cdd::Cddal.serialize(db)
  expect(out1).to eq(out2)
end
```

Catches accidental `Hash#each`-order dependencies.

### Snapshot tests (opt-in)

`spec/snapshots/` directory holds canonical serialized outputs:

```
spec/snapshots/oceanrunner.cddal        # checked in
spec/snapshots/oceanrunner.json
spec/snapshots/oceanrunner.mermaid
```

Spec compares current serializer output to the snapshot. To regenerate:

```bash
SNAPSHOT_REGEN=1 bundle exec rspec spec/snapshot_spec.rb
```

Snapshot diff is shown on failure. Reviewer approves by re-running with
`SNAPSHOT_REGEN=1` and committing the new file.

### Property registry invariant specs

From `cdd-data/specs/parcelmaker/05_test_cases.md`:

```ruby
it "exposes every registered ID as a constant" do
  Cdd::PropertyIds::REGISTRY.each_key do |id|
    expect(Cdd::PropertyIds.const_get(id)).to eq(id)
  end
end

it "uses MDC_C011 for Relation" do
  expect(Cdd::MetaClasses.find_by_code("MDC_C011").name).to eq("Relation")
end

it "reads property.data_type from MDC_P022" do
  prop = Cdd::Property.new(properties: { Cdd::PropertyIds::MDC_P022 => "REAL_TYPE" })
  expect(prop.data_type.to_s).to eq("REAL_TYPE")
end
```

These guard against regressions of plan 02.

### Performance baseline (informational)

`spec/performance_spec.rb` (skipped unless `--profile`):

```ruby
it "parses IEC62683 xlsx in under 2 seconds" do
  expect { read_fixture }.to perform_under(2).sec
end
```

Not gating; just for tracking regressions.

### Acceptance spec coverage

Every feature in `cdd-data/specs/parcelmaker/01_features.md` that the
Ruby gem owns has at least one spec in `spec/`. The current 41 spec
files + plan 09's `modules_spec.rb` + this plan's matrix cover the full
F01–F30 list (Ruby-owned subset).

## Acceptance criteria

- [x] `Cdd::Database#semantically_equal?` defined and spec'd.
- [x] Every cell in the round-trip matrix has a spec; all green.
- [x] Serializer determinism specs pass (10× repeat, identical bytes).
- [x] Snapshot tests pass (or are explicitly regenerated with a
      documenting commit).
- [x] Property-registry invariant specs cover the discrepancies fixed
      in plan 02.
- [x] `bundle exec rspec` total count is reported in CI; trend tracked.
- [x] No spec uses `double()`.

## Dependencies

- **All format plans (06, 07, 08, 09, 11)** — without these there's
  nothing to round-trip.
- **Plan 02** — registry fixes are needed for parity assertions.
- **Plan 05** — Database owns `semantically_equal?`.

## Open questions

- **Q1.** Should the legacy `.xls` reader be in the round-trip matrix
  given we can't write `.xls`? **Recommendation:** yes — read-only
  parity with ParcelMaker is a meaningful guarantee.
- **Q2.** Snapshot regeneration workflow? **Recommendation:** require
  PR reviewer approval; never auto-regenerate in CI.
- **Q3.** Should the snapshot tests pin the exact CDDAL byte sequence,
  or just semantic equality? **Recommendation:** pin bytes — catches
  accidental reordering, which is the main determinism risk.
