# Plan 25 — Round-trip test matrix

## Why

Plan 12 specified a structured round-trip test matrix. The current
ad-hoc tests cover the cases that worked; the case that didn't
(CDDAL → Parcel for non-Class entities) was missing and that's why
the round-trip bug lingered.

## Scope

`spec/parcel/round_trip_matrix_spec.rb` — formal matrix of fixture ×
transformation pairs. Each cell asserts semantic equality between
source and result.

## Matrix

| From → To         | OceanRunner | Kagoshima | Synthetic-per-type |
|--------------------|:-----------:|:---------:|:------------------:|
| CDDAL → CDDAL      | ✅          | ✅        | ✅                 |
| CDDAL → Parcel     | ✅          | ✅        | ✅                 |
| Parcel → CDDAL     | n/a         | n/a       | ✅ (synthesis)     |
| Parcel → Parcel    | n/a         | n/a       | ✅ (synthesis)     |
| CDDAL → JSON → CDDAL | ✅        | ✅        | ✅                 |

## Acceptance

- [x] Matrix spec exists with one example per cell.
- [x] All cells pass after P24 (Parcel round-trip fix).
- [x] A failing cell would have caught the original P24 bug.

## Dependencies

- **Plan 24** — Parcel round-trip fix.
