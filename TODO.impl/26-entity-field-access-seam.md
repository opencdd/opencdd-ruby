# Plan 26 — Tighten Entity interface — properties hash leaks to 5 callers

## Why

Five modules index `entity.properties[pid]` directly, bypassing the
Field DSL that already owns typed access:

- `lib/opencdd/parcel/sheet_emitter.rb:146-158` — multilingual fallback reimplemented
- `lib/opencdd/guid.rb:20` — writes through the hash
- `lib/opencdd/relation_tree.rb:65` — reads raw properties
- `lib/opencdd/cddal/builder.rb:378-392` — iterates raw hash for reference properties
- `lib/opencdd/exporters/json.rb:215` — raw_properties dump

The Field DSL already knows about multilingual fields, value kinds,
and synthetic fields. Bypassing it risks:
- Round-trip inconsistency (SheetEmitter and Json can disagree)
- Newly added typed accessors invisible to these callers
- FieldRegistry metadata (value_kind, multilingual) duplicated as ad-hoc checks

## Scope

Two changes:

1. Add `Entity#read_field(name, lang: nil)` as the public,
   FieldRegistry-aware read API. Used by SheetEmitter instead of its
   private multilingual fallback.
2. Add `Entity#write_property!(id, value)` as the public write API.
   Used by `Opencdd::GUID.set_on` instead of `entity.properties[id] = value`.

The raw `properties` hash stays accessible (Parcel readers need it
for lossless read), but non-infrastructure callers go through the
field seam.

## Approach

```ruby
class Opencdd::Entity
  def read_field(name, lang: nil)
    Opencdd::Entity::FieldReader.read(self, name, lang: lang)
  end

  def write_property!(id, value)
    # Routes through the canonical id (alias resolution) so writes
    # are consistent with reads.
    canonical = Opencdd::PropertyIds.canonical_id(id.to_s)
    base = canonical.to_s.split(".").first
    @properties[base] = value.to_s
    self
  end
end
```

Migrate the five call sites.

## Acceptance

- [x] `Entity#read_field` exists and is the SSOT for field reads.
- [x] `Entity#write_property!` exists.
- [x] SheetEmitter uses `read_field` instead of inline multilingual fallback.
- [x] GUID uses `write_property!`.
- [x] All 757 existing specs pass.

## Dependencies

None.
