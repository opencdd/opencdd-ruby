# Plan 32 — Specs for Languages + InstanceRule

## Why

`Opencdd::Languages` (70 lines) and `Opencdd::InstanceRule` (70
lines) have zero spec coverage. `InstanceRule` has cartesian-product
expansion with exception filtering — exactly the algorithmic code
that needs specs.

## Scope

Two new spec files:

- `spec/languages_spec.rb` — source/translation language list,
  multilingual value access, equality.
- `spec/instance_rule_spec.rb` — cartesian product across groups,
  exception filtering, empty group edge cases.

## Approach

Use the IEC 61360 manual's example: 3 groups with cardinalities
2×3×2 → 12 instances; one exception → 11. Spec both the generate
path and the exception filter.

## Acceptance

- [x] `spec/languages_spec.rb` exists with ≥5 specs.
- [x] `spec/instance_rule_spec.rb` exists with ≥5 specs.
- [x] All specs pass.

## Dependencies

None.
