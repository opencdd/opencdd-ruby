# Plan 23 — Split `ShardedDirReader` at the JSON / XLS seam

## Why

`ShardedDirReader` is 238 lines handling three concerns:

1. **Directory layout detection** (~60 lines) — class-code/UNID/version
   patterns. Will be replaced by `LayoutDetector` from plan 19.
2. **`_entity.json` parsing** (~80 lines) — JSON-to-`VersionHistory`
   conversion + stub-entity creation. Self-contained, has nothing to
   do with XLS reading.
3. **XLS delegation** (~30 lines) — calls `FlatDirReader` per subdir.

The `_entity.json` parsing is particularly hard to test in isolation
because it requires a full directory tree on disk.

## Scope

Extract `Opencdd::Parcel::EntityManifest` — owns the harvester's
`_entity.json` sidecar format. `ShardedDirReader` becomes a thin
orchestrator: `LayoutDetector` + `EntityManifest` + `FlatDirReader`.

## Approach

```ruby
class Opencdd::Parcel::EntityManifest
  def self.read(entity_dir)       # → Manifest or nil
  def version_history             # → VersionHistory
  def entity_json                 # → Hash (parsed _entity.json)
  def current_version_dir         # → String (UNID) or nil
  def to_stub_entity(meta_class_code)  # → Entity or nil
end
```

`ShardedDirReader` flow:
```ruby
def load_into(database)
  class_subdirs.each do |subdir|
    manifest = Opencdd::Parcel::EntityManifest.read(subdir)
    active = Opencdd::Parcel::LayoutDetector.active_xls_dir(subdir)
    next unless active
    workbook = Opencdd::Parcel::FlatDirReader.new(active).read_workbook
    database.add_workbook(workbook)
    attach_manifest(database, subdir, manifest) if manifest
  end
  database.finalize!
end
```

## Acceptance

- [x] `EntityManifest` exists with `read`, `version_history`,
      `current_version_dir`, `to_stub_entity`.
- [x] `ShardedDirReader` is a thin orchestrator (target: <80 lines).
- [x] Manifest parsing is testable with a hash fixture, no disk.
- [x] Spec covers the manifest independently.
- [x] All existing ShardedDirReader specs pass (with harvester fixtures).

## Dependencies

- **Plan 19** — `LayoutDetector` extracted first.
- **Plan 17** — optional, but cleaner with shared collection parsing.
