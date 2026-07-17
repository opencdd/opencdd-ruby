# 02 — Per-entity JSON emit (Ruby)

## Why

The browser downloads JSON for an entity by serializing the on-page
node. This is fine for the page payload, but consumers (CLI users,
data pipelines) also want to extract one entity from a database
without writing Ruby.

The exporter already has a `visit_*` per-entity method chain
(`visit_class`, `visit_property`, …) — each is one entity-type
specialization of the same shape. There is no single
`entity_payload(entity)` entry point because the original design
only emitted whole databases.

## What

Promote the per-entity visit_* methods to a single public dispatch
that accepts any entity. Use the entity's class to pick the visitor
— but via a class-side registry, not a `case/when` (OCP).

## How

- File: `lib/opencdd/exporters/json.rb`
  - Extract a class-level `EntityNodeBuilders` registry: each entity
    class registers its node-builder proc on load (no central switch).
  - Add `Json#entity_payload(entity)` — public, returns a `Hash`.
  - Each `visit_*` method delegates to the registry.
- File: `lib/opencdd/exporters.rb`
  - No new autoload needed — `Json` is already autoloaded there.

## Acceptance

- `Opencdd::Exporters::Json.new.entity_payload(entity)` returns a `Hash` matching the wire format for any of the 7 entity types.
- Output is identical to the per-entity slice that `to_json` would have produced for that entity in a database.
- New spec: `spec/exporters/per_entity_json_spec.rb` covering all 7 entity types.
- No `case/when` on entity type in `json.rb`.

## Status

Pending.
