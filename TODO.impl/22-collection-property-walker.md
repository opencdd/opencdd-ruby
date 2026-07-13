# Plan 22 — Fold two collection walkers into one

## Why

`Database#normalize_reference_collections!` and
`Database#rewrite_back_references!` share 80% of their structure:
iterate all entities × all properties, filter to `set_of_refs`,
unwrap the collection, apply a transform, write back. Only the
transform differs (paren-to-brace vs IRDI substitution).

If a new value-kind is added (e.g. a hypothetical
`ordered_set_of_refs`), both methods must be updated independently.

## Scope

Add `Database#each_set_of_refs` (private) that yields
`(entity, property_id, elements)` tuples. Both callers reduce to a
one-liner transform.

## Approach

```ruby
def each_set_of_refs
  return enum_for(:each_set_of_refs) unless block_given?
  ids = self.class.reference_set_property_ids
  entities.each do |entity|
    ids.each do |pid|
      raw = entity.properties[pid]
      next if raw.nil? || raw.to_s.strip.empty?
      elements = Opencdd::StructuredValues.unwrap_and_split(raw)
      yield(entity, pid, elements)
    end
  end
end

def normalize_reference_collections!
  each_set_of_refs do |entity, pid, elements|
    entity.properties[pid] = Opencdd::StructuredValues.rejoin(elements)
  end
  self
end

def rewrite_back_references!(...)  # uses each_set_of_refs
  each_set_of_refs do |entity, pid, elements|
    mapped = elements.map { |e| e == old_irdi.to_s ? new_irdi.to_s : e }
    entity.properties[pid] = Opencdd::StructuredValues.rejoin(mapped)
  end
end
```

## Acceptance

- [x] `each_set_of_refs` exists and is the single iteration shape.
- [x] Both methods reduce to a transform lambda.
- [x] New value-kind additions only touch the iteration, not each caller.
- [x] Spec covers `each_set_of_refs` directly with synthetic entities.

## Dependencies

- **Plan 17** — uses `StructuredValues.unwrap_and_split` / `rejoin`.
