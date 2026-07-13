# Plan 18 — Cut `Entity#type`'s dependency on the Parcel namespace

## Why

`Entity#type` — the most fundamental entity discriminator — resolves
via `Opencdd::Parcel::META_CLASS_TYPES`, which is just an alias for
`Opencdd::MetaClasses::TYPE_BY_META_CLASS`. The core model entity
reaches into the Parcel format namespace for its own identity.

`MetaClasses.type_for(irdi)` already exists. The Parcel re-export
exists only for legacy convenience, yet the model depends on it.

## Scope

One-line fix in `lib/opencdd/entity.rb`. The Parcel re-export stays
for back-compat with external callers (FlatDirReader, Metadata) but
the model no longer needs it.

## Approach

```ruby
# Before:
def type
  Opencdd::Parcel::META_CLASS_TYPES[meta_class_irdi&.code]
end

# After:
def type
  Opencdd::MetaClasses.type_for(meta_class_irdi&.code)
end
```

## Acceptance

- [x] `Entity#type` no longer references `Opencdd::Parcel`.
- [x] `Opencdd::Parcel::META_CLASS_TYPES` still exists (back-compat).
- [x] All entity specs still pass.

## Dependencies

None. Bundle with #17 — same PR.
