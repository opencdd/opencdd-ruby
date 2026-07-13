# Plan 31 — Codegen::Ts spec coverage + in-memory seam

## Why

`Opencdd::Codegen::Ts` (179 lines) is the only production module
in `lib/opencdd/` with zero spec files. Writes to disk. Duplicates
schema knowledge from `PropertyIds::REGISTRY` and `MetaClasses` as
string interpolation.

## Scope

Add an in-memory emit seam so tests can assert generated output
without touching the filesystem.

## Approach

```ruby
class Opencdd::Codegen::Ts
  def generate_property_ids  # → String (no file write)
  def generate_meta_classes  # → String
  def write_file(...)        # → wraps the above + File.write
end
```

Spec the generated strings: assert they parse as valid TS, include
expected constants, and round-trip with `rake generate_ts`.

## Acceptance

- [x] `spec/codegen/ts_spec.rb` exists.
- [x] Generate methods return strings (no disk).
- [x] File write is the thin wrapper.
- [x] Specs cover: PropertyIds registry contents, MetaClasses
      registry contents, header/footer, freeze declarations.

## Dependencies

None.
