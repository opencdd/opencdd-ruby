# 08 — Per-version JSON build pipeline

## Why

Time-travel (TODO 07) and diff view (TODO 09) both need per-version
JSON. The current `rake browser:build[dict]` only emits the current
version's JSON.

## What

A new rake task that emits `entity/<code>/v/<version_unid>.json`
for every entity with `versions.length > 1`. Uses the new
VersionedReader (TODO 03) to load each historical version.

## How

- Repo: `cdd-data/Rakefile`
  - New task: `browser:build_versions[dict]`.
  - For each entity with multi-version history:
    - For each non-current version:
      - `VersionedReader.new(src_dir).load_version(code, unid)`
      - `Exporters::Json.new.entity_payload(entity)` (TODO 02)
      - Write to `data/<dict>/entity/<code>/v/<unid>.json`.
- Repo: `cdd-data/cdd.config.yml`
  - Document the new output directory.
- Repo: `opencdd.github.io`
  - `src/content/data/<dict>/entity/<code>/v/<unid>.json` ships in the data sync.
  - Optional: a manifest at `data/<dict>/version-manifest.json` listing all available versions per entity, to avoid 404s in the UI.

### Performance

- For iec61987 (24,896 version entries, 5,715 multi-version entities): ~6,500 historical JSON files.
- Each file ~3-30KB → ~100MB total. Acceptable.
- Build time: ~6,500 file reads via VersionedReader. Should be <10 minutes.
- Lazy: only emit for entities with >1 version (current version is already in `database.json`).

## Acceptance

- `rake browser:build_versions[iec63213]` produces 28 historical JSON files (28 multi-version entities in iec63213).
- Each file is valid JSON, parses to an `EntityNode` shape.
- The `unid` in the filename matches `_entity.json#versions[].unid` for that version.
- New spec in `cdd-data` (or smoke test): file count matches expected.

## Status

Pending — blocked on TODOs 02 (per-entity JSON) and 03 (VersionedReader).
