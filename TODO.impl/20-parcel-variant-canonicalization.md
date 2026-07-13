# Plan 20 — Move `PARCEL_VARIANT_TO_CANONICAL` out of the ontology registry

## Why

`Opencdd::PropertyIds::PARCEL_VARIANT_TO_CANONICAL` maps Parcel-sheet
column IDs (`MDC_P004_1` → `MDC_P004`) that exist only because IEC
62656-1 Parcel Excel uses distinct column headers for localized vs
canonical properties. This mapping is consumed only by
`Opencdd::Parcel::SheetSchema#finalize!` — one call site. Yet it
lives in the domain-wide `PropertyIds` module alongside
`canonical_id` and `normalize`, suggesting it's part of the core
ontology.

Callers outside Parcel (CDDAL, JSON exporters, validators) never
need Parcel-specific canonicalization, but they have accidental
access to it because it's on the wrong module.

## Scope

Move:
- `PropertyIds::PARCEL_VARIANT_TO_CANONICAL` →
  `Opencdd::Parcel::SheetSchema::VARIANT_TO_CANONICAL`
- `PropertyIds.canonical_parcel_id` →
  `Opencdd::Parcel::SheetSchema.canonical_id`

`PropertyIds` becomes purely about the ontology.

## Approach

1. Add `VARIANT_TO_CANONICAL` constant + `canonical_id(raw)` class
   method to `Opencdd::Parcel::SheetSchema`.
2. Update `SheetSchema#finalize!` to use the local constant.
3. Remove from `PropertyIds`.
4. Add deprecation aliases (Ruby `def self.canonical_parcel_id; ...; end`)
   on `PropertyIds` that warn and delegate, for one release cycle.

## Acceptance

- [x] `PARCEL_VARIANT_TO_CANONICAL` no longer in `property_ids.rb`.
- [x] `SheetSchema::VARIANT_TO_CANONICAL` exists.
- [x] Only `SheetSchema` references the constant.
- [x] Deprecation spec covers the back-compat alias.

## Dependencies

None.
