# Plan 29 — Visitor traversal strategy seam

## Why

`Opencdd::Visitor#visit_database` hardcodes traversal order
(classes → properties → units → value_lists → value_terms →
relations → view_controls). Adding a new entity type, filtering,
or changing order requires editing the base class.

Sort-by-code is duplicated across Visitor, Json exporter, Mermaid
exporter, and Cddal::Serializer (~8 sites).

## Scope

Introduce a `Traversal` strategy:
- Iterate entity types in registry order by default.
- Accept a `filter:` and `order:` proc for variations.
- Sort-by-code lives on Traversal, not on each caller.

## Approach

```ruby
class Opencdd::Visitor
  def visit_database(db, &block)
    Opencdd::EntityTraversal.each_typed(db, &block)
  end
end

module Opencdd::EntityTraversal
  module_function
  def each_typed(db)
    db.entities.group_by(&:type).sort.each do |type, entities|
      entities.sort_by { |e| e.code.to_s }.each { |e| yield(e) }
    end
  end
end
```

## Acceptance

- [x] Sort-by-code lives in `EntityTraversal`, not duplicated.
- [x] Visitor's `visit_database` delegates.
- [x] Mermaid exporter doesn't override `visit_database` to skip sorts.
- [x] All specs pass.

## Dependencies

None.
