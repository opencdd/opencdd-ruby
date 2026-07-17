# 04 — Entity diff engine (Ruby)

## Why

The browser's VersionTimeline shows that an entity has multiple
versions, but doesn't show *what changed*. To answer "what's
different between v002 and v003 of KEA012?" the user has to
download both CDDAL fragments and diff them by hand.

A structured diff engine gives:
- The browser a clean wire object to render a visual diff (TODO 09).
- CLI users a quick "what changed" inspection tool.
- Auditors a way to spot check unwanted edits between releases.

## What

A new `Opencdd::EntityDiff` value object that computes a
structured diff between two entities of the same IRDI. Returns
`added`, `removed`, and `changed` field lists with old/new values.

## How

- File: `lib/opencdd/entity_diff.rb` (new)
  - `EntityDiff.between(entity_a, entity_b)` — constructor.
  - `EntityDiff#added` → `Array<String>` (field names in B not in A).
  - `EntityDiff#removed` → `Array<String>` (in A not in B).
  - `EntityDiff#changed` → `Array<{ field:, from:, to: }>` (different values).
  - `EntityDiff#empty?` → bool.
  - Iterates `entity.properties` (the lutaml-model field registry) — no type dispatch.
  - Multilingual fields (`.en`, `.de` suffixes) are diffed as a group, not per-suffix.
- File: `lib/opencdd.rb`
  - Add `autoload :EntityDiff, "opencdd/entity_diff"`.

## Acceptance

- Two entities with the same IRDI but different `preferred_name` produce `changed: [{ field: "preferred_name", from: "X", to: "Y" }]`.
- Adding a property produces `added: ["MDC_P999"]`.
- No `case/when` on entity type.
- New spec: `spec/entity_diff_spec.rb` covering:
  - Identical entities → empty diff.
  - One field changed.
  - Field added / removed.
  - Multilingual field group diff.
  - Different entity types → raises clear error.
- No `send` / `instance_variable_*` / `respond_to?`.

## Status

Pending.
