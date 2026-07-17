# 21 — Documentation: update CLAUDE.md / README for new features

## Why

After TODOs 01–20 ship, the docs are stale:
- CLAUDE.md doesn't mention `EntityDiff`, `VersionedReader`, `emit_entity`, `payload_for`, or `browser:build_parcel`.
- README doesn't mention the new download formats or time-travel UI.
- TODO.final/README has the truth but is internal-only.

## What

Update CLAUDE.md (opencdd-ruby), README (opencdd.github.io),
and the docs section (`src/content/docs/`) to reflect the new
surface.

## How

- File: `opencdd-ruby/CLAUDE.md`
  - Add the new public API methods under "The `cdd` gem" section.
  - Note the data pipeline additions (`browser:build_versions`, `browser:build_parcel`).
- File: `opencdd.github.io/README.md`
  - Update the routes table (add `/d/:dict/changes`, `/stats`).
  - Update the architecture diagram with the new components.
- File: `opencdd.github.io/src/content/docs/using-cdd-data.mdx`
  - New "Downloads" section: Parcel, JSON, CDDAL, CSV.
  - New "Version history" section: time travel, diff view.

## Acceptance

- All three docs updated.
- Internal links work.
- No content claims features that don't exist.

## Status

Pending.
