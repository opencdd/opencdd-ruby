# 09 — Browser: diff view

## Why

Once time-travel works (TODO 07), the natural next step is "show me
what changed between v002 and v003". Currently the user can switch
between versions but has to spot differences manually.

## What

A new `VersionDiff.vue` component that calls the Ruby
`Opencdd::EntityDiff` engine (TODO 04) — but client-side, since the
browser is static. Two paths:

1. **Build-time diff**: pre-compute diffs between adjacent versions during `rake browser:build_versions`. Emit `<code>/diff/<from>-<to>.json`.
2. **Runtime diff**: compute in TS from two version JSON files.

Pick **runtime diff** — simpler, no per-pair emit. The TS port of
EntityDiff is small (just iterate `raw_properties` and compare).

## How

- File: `src/lib/entityDiff.ts` (new)
  - Port of `Opencdd::EntityDiff` (TODO 04).
  - `entityDiff(entityA, entityB): { added, removed, changed }`.
- File: `src/components/islands/VersionDiff.vue` (new)
  - Modal triggered from VersionTimeline ("Diff against current" button).
  - Renders added/removed/changed fields with color coding.
- File: `src/components/islands/VersionTimeline.vue`
  - Each past version gets a "Diff" button next to "Show source files".
- File: `src/styles/global.css`
  - Tokens for diff colors: `--color-diff-added`, `--color-diff-removed`, `--color-diff-changed`.

### Visual treatment

- Side-by-side or unified view (toggle).
- Added fields: emerald left border.
- Removed fields: rose left border.
- Changed fields: amber left border + strikethrough old value.
- Diff stats in header: "+3 -1 ~2".

## Acceptance

- Diff button on `/d/iec63213/c/KEA012?` v001 vs current shows the differences.
- Diff handles multilingual fields as a group.
- No `: any` in diff code.
- New spec: `tests/lib/entityDiff.test.ts` covering add/remove/change/multilingual.

## Status

Pending — blocked on TODO 07 (time-travel infrastructure).
