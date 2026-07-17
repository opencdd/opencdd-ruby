# 12 — Spec coverage for new features

## Why

Every new public method needs specs. The TODOs 01-04 introduce:
- `Cddal::Serializer#emit_entity`
- `Exporters::Json#entity_payload`
- `Parcel::VersionedReader#versions_for` / `#load_version`
- `EntityDiff.between` and friends

## What

Audit each new method and ensure:
1. Happy-path spec.
2. Edge cases (empty input, nil, off-diagonal types).
3. Round-trip where applicable (CDDAL emit → parse → equivalent).
4. Wire-format invariants where applicable (JSON shape matches TS types).

## How

- File: `spec/cddal/per_entity_emit_spec.rb` (new) — TODO 01.
- File: `spec/exporters/per_entity_json_spec.rb` (new) — TODO 02.
- File: `spec/parcel/versioned_reader_spec.rb` (new) — TODO 03.
- File: `spec/entity_diff_spec.rb` (new) — TODO 04.

Also: extend `spec/code_quality_spec.rb` (the existing code-quality
spec) to forbid:
- `require_relative` in `lib/`
- `instance_variable_set` / `instance_variable_get` in `lib/`
- `respond_to?` in `lib/`
- `.send(` / `.__send__(` (public_send is allowed for framework
  integration, audited case-by-case).

## Acceptance

- `bundle exec rspec` is green for all new specs.
- The code-quality spec catches the four forbidden patterns.
- Coverage report (if running `simplecov`) shows >95% on new files.

## Status

Pending — final pass after TODOs 01-04 land.
