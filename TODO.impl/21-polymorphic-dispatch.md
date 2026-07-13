# Plan 21 — Replace `is_a?` dispatch chains with polymorphism

## Why

Two flavors of type-dispatch leak:

1. **`Opencdd::DataType#reference?`** is a chain across three
   subclasses (`ClassReference`, `EnumStringType`, `EnumReferenceType`)
   when each subclass already has its own predicate. Adding a new
   reference subtype means editing the chain.

2. **`Opencdd::CompositionTree`** has 7 `is_a?(Opencdd::Klass)`
   checks in 116 lines. The pattern is always: "resolve this value,
   check if it's a Klass, then proceed." Adding a new entity type
   that should participate in composition trees means finding every
   chain and patching it.

## Scope

Two cleanups, separable:

### (a) DataType predicate override — small, do first

```ruby
class Opencdd::DataType::ClassReference
  def reference? = true
end
class Opencdd::DataType::EnumStringType
  def reference? = true
end
class Opencdd::DataType::EnumReferenceType
  def reference? = true
end
class Opencdd::DataType::Primitive   # default
  def reference? = false
end
```

`DataType.reference?` (top-level) delegates to the subclass. No chain.

### (b) Entity visitor for CompositionTree — larger, do second

```ruby
class Opencdd::Entity
  def accept_visitor(visitor) = visitor.visit_unknown(self)
end
class Opencdd::Klass
  def accept_visitor(visitor) = visitor.visit_klass(self)
end
class Opencdd::Property
  def accept_visitor(visitor) = visitor.visit_property(self)
end
```

`CompositionTree` defines `visit_klass`, `visit_property`,
`visit_unknown`. No `is_a?` checks.

## Approach

Implement (a) first — three-line per subclass change. Then (b).

For (b), keep the existing `CompositionTree` interface stable. The
internal dispatch moves from `is_a?` to `accept_visitor`.

## Acceptance

- [x] `DataType#reference?` no longer uses `is_a?`.
- [x] `CompositionTree` no longer uses `is_a?(Opencdd::Klass)` etc.
- [x] New entity subclass auto-participates in tree via `accept_visitor`.
- [x] All existing specs pass.
- [x] New spec covers `visit_unknown` for unrecognised entity types.

## Dependencies

None. Independent of #17/#19.
