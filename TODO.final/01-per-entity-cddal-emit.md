# 01 — Per-entity CDDAL emit (Ruby)

## Why

The browser's DownloadMenu emits CDDAL client-side via a TS port
(`src/lib/cddalEmitter.ts`). This works but has two problems:

1. **Drift risk** — the TS port is a parallel implementation of the
   CDDAL wire format. When the Ruby serializer evolves, the TS port
   silently drifts. There is no spec tying them together.
2. **Single-source-of-truth violation** — the Ruby serializer is the
   canonical implementation; the browser should consume its output
   (via a pre-built per-entity CDDAL file emitted at build time) or
   call into it. Currently it does neither.

The cleaner architecture: Ruby serializer exposes a public
`emit_entity(entity)` method. The build pipeline can call it per
entity to emit `entity/<code>.cddal` files. The browser's TS port
becomes a fallback only.

## What

Add `Opencdd::Cddal::Serializer#emit_entity(entity)` — public
method that returns the CDDAL text for one entity. Refactor the
existing private `emit_instance` to delegate to it (DRY).

## How

- File: `lib/opencdd/cddal/serializer.rb`
  - Make `emit_instance(entity)` return the lines array (current behavior, kept for back-compat).
  - Add `emit_entity(entity)` that returns the joined text for one entity (with header).
  - Both share a private `emit_instance_lines(entity)` helper.
- No new autoload needed — `Cddal::Serializer` is already autoloaded via `lib/opencdd/cddal.rb`.

## Acceptance

- `Opencdd::Cddal::Serializer.new(db).emit_entity(entity)` returns a `String`.
- Output is valid CDDAL: round-trips through `Opencdd::Cddal.parse` into an equivalent entity.
- The existing `to_cddal` output is unchanged.
- New spec: `spec/cddal/per_entity_emit_spec.rb` covering all 7 entity types.
- Existing `spec/cddal_spec.rb` still passes.

## Status

Pending.
