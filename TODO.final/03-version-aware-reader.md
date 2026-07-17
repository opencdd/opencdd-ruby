# 03 — Version-aware reader (Ruby)

## Why

`ShardedDirReader` only reads the *current* version of each entity.
The on-disk layout has *every* version's xls files in a per-UNID
subfolder, but the reader picks just `current_version_dir` and
discards the rest.

This blocks:
- The browser's time-travel UI (TODO 07) — no way to load v002's content.
- The diff engine (TODO 04) — needs both versions' entities to diff.
- Audit / reproducibility — "what did this class look like in 2022?"

## What

A new `Opencdd::Parcel::VersionedReader` (or extending
`ShardedDirReader`) that can:

- List all versions for an entity (`versions_for(code)`)
- Load a specific version's content as a standalone `Database` (`load_version(code, unid)`)

## How

- File: `lib/opencdd/parcel/versioned_reader.rb` (new)
  - Wraps a ShardedDirReader path.
  - `versions_for(code)` → array of `EntityManifest::Version` (or equivalent value objects).
  - `load_version(code, unid)` → `Database` containing just that version's xls content.
- File: `lib/opencdd/parcel.rb`
  - Add `autoload :VersionedReader, "opencdd/parcel/versioned_reader"` (OCP: no edits to existing classes).
- Reuse: delegates to `Opencdd::Parcel::FlatDirReader` for the
  actual xls reading of one version's folder.

## Acceptance

- `VersionedReader.new(path).versions_for("KEA012")` returns 3 versions for the iec63213 KEA012 fixture.
- `VersionedReader.new(path).load_version("KEA012", "c7b602fc...")` returns a Database whose single class has the v002 shape.
- New spec: `spec/parcel/versioned_reader_spec.rb` using iec63213 fixture.
- No `send` / `instance_variable_*` / `respond_to?`.

## Status

Pending.
