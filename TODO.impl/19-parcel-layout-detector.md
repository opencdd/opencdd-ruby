# Plan 19 — Extract `Opencdd::Parcel::LayoutDetector` from three readers

## Why

Directory-layout detection is reimplemented four times:

- `Opencdd::Reader::SHARDED_CLASS_CODE` ≡
  `Opencdd::Parcel::ShardedDirReader::CLASS_CODE_PATTERN`
- `Opencdd::Reader#sharded_class_subdir?` reimplements the same
  `_entity.json` / UNID / legacy-file detection as
  `Opencdd::Parcel::ShardedDirReader#active_xls_dir`.
- The `legacy?` regex is copy-pasted in `Reader`,
  `FlatDirReader`, `ShardedDirReader`.
- `FILE_PATTERN` is duplicated between `FlatDirReader` and
  `ScrapeVerifier`.

When the harvester emits a new variant, every reader drifts
independently.

## Scope

New file: `lib/opencdd/parcel/layout_detector.rb`. Pure functions
over directory paths. Each reader delegates.

## Approach

```ruby
module Opencdd::Parcel::LayoutDetector
  CLASS_CODE_PATTERN = /\A[A-Z]{2,6}[0-9]{1,6}[A-Z0-9-]*\z/.freeze
  UNID_PATTERN       = /\A[0-9A-F]{32}\z/i.freeze
  FILE_PATTERN       = /\Aexport_(CLASS|PROPERTY|RELATION|UNIT|VALUELIST|VALUETERMS)_[^\.]+\.(xls|xlsx)\z/i.freeze

  module_function

  def class_code?(name)        ; ... end
  def legacy_export?(filename) ; ... end
  def active_xls_dir(code_dir) ; ... end
end
```

Each reader:
```ruby
# Reader.rb
def sharded_class_subdir?(path)
  Opencdd::Parcel::LayoutDetector.class_code?(File.basename(path)) &&
    Dir.exist?(path)
end

# ShardedDirReader.rb
def active_xls_dir(code_dir)
  Opencdd::Parcel::LayoutDetector.active_xls_dir(code_dir)
end
```

## Acceptance

- [x] `LayoutDetector` exists with the four constants and three methods.
- [x] All duplicated constants and methods removed from readers.
- [x] `grep -rn "export_(CLASS|PROPERTY" lib/opencdd/` returns only
      `LayoutDetector::FILE_PATTERN`.
- [x] New spec covers all detection variants (per-version UNID,
      flat, legacy, non-class dir).
- [x] All 700+ specs still pass.

## Dependencies

None. Enables #23 (ShardedDirReader split).
