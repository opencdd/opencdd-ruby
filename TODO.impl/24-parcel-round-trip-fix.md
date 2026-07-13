# Plan 24 — Fix Parcel round-trip dropping Property/ValueList/Unit/Relation entities

## Why

The Parcel writer round-trip drops 50% of entities:

```ruby
db = Opencdd::Cddal.parse_file("oceanrunner.cddal")  # 40 entities
Opencdd::Parcel::Writer.new(db).write("out.xlsx", parcel_id: "OCEAN")
db2 = Opencdd::Database.load("out.xlsx")
db2.entities.size  # => 20 (only classes survive; 19 properties + 1 value_list lost)
```

### Root cause

CDDAL's `code` alias is hardcoded to `MDC_P001_5` (the **Class** code
property). When the CDDAL Builder processes `code: AAAP001` on a
Property, it stores the value under `MDC_P001_5`.

But each meta-class has its own canonical code property per IEC 62656-1:

| Meta-class   | Code property |
|--------------|---------------|
| Class        | `MDC_P001_5`  |
| Property     | `MDC_P001_6`  |
| Unit         | `MDC_P001_10` |
| ValueTerm    | `MDC_P001_11` |
| ValueList    | `MDC_P001_12` |
| Relation     | `MDC_P001_13` |
| ViewControl  | `EXT_P001`    |

The Parcel reader looks up each entity's code under its meta-class's
canonical code property. For a Property, that's `MDC_P001_6`. The
writer emits columns for both `MDC_P001_5` and `MDC_P001_6`, but the
CDDAL-sourced data only fills `MDC_P001_5`. So `MDC_P001_6` is nil
on the Property sheet → IRDI parses as nil → entity dropped.

## Scope

Make `code` alias resolution context-aware in the CDDAL Builder.
When building an instance, resolve `code` against the meta-class's
canonical code property (via `MetaClasses.code_property_id_for`).

The change is local to `Opencdd::Cddal::Builder#build_properties`
— it now passes the meta-class context to `resolve_property_id`.

## Approach

1. Add `Builder#resolve_property_id(name, meta_class_code:)` that:
   - Returns the canonical code property ID when `name` resolves to
     a code alias (`code`, `code_generic`, `code_class`) AND the
     target ID differs from the meta-class's canonical code.
   - Falls back to current behavior otherwise.
2. `build_properties` passes the instance declaration's meta-class.
3. Reader side: also accept `MDC_P001_5` as a fallback code source
   for any entity, so already-emitted (broken) Parcel files still
   read.
4. Spec: OceanRunner round-trip preserves all 40 entities.

## Acceptance

- [x] OceanRunner → Parcel xlsx → Database: 40 entities, 0 dropped.
- [x] Kagoshima sample round-trips cleanly.
- [x] Property's code reads back under `MDC_P001_6` after round-trip.
- [x] Existing 748 specs still pass.
- [x] New round-trip spec in `spec/parcel/round_trip_spec.rb` covers
      the full entity-type matrix.

## Dependencies

None. The bug is the root cause of plan 12's "round-trip drift".

## Out of scope

The `MDC_P005` / `MDC_P006` / `MDC_P007` collision (canonical IDs
that overlap with ParcelMaker variant IDs) is a separate issue —
tracked in `TODO.impl/06-parcel-format.md` as a known limitation.
