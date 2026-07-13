# Plan 28 — Split Cddal::Builder — import pipeline vs. property assembler

## Why

`Opencdd::Cddal::Builder` (414 lines) owns two structurally
independent pipelines:

1. **Import pipeline** (lines 110-183): cycle detection, recursive
   sub-document build, bare/qualified/selective scoping.
2. **Property assembly pipeline** (lines 247-411): assignment-to-properties
   compilation, value serialization, reference resolution.

They share `@database` and `@alias_table` state but otherwise
decompose independently. The interleaving makes both harder to
reason about — adding a new import feature (e.g. versioning)
shouldn't touch property assembly, and vice versa.

## Scope

Extract two collaborators behind the Builder:

- `Opencdd::Cddal::ImportResolver` — owns module resolution,
  cycle detection, scope application. Takes a database, resolver,
  fetcher, and source_file; returns after applying all imports.
- `Opencdd::Cddal::PropertyAssembler` — owns assignment-to-properties
  compilation: alias resolution, value serialization, reference
  resolution.

The Builder becomes a thin orchestrator that wires them in order.

## Approach

```ruby
class Opencdd::Cddal::Builder
  def build(document)
    document = wrap_document(document)
    apply_alias_declarations(document)
    apply_meta_class_declarations(document)
    Opencdd::Cddal::ImportResolver.new(@database, resolver: @resolver, ...).apply(document)
    register_instance_symbols(document)
    instantiate_entities(document)
    Opencdd::Cddal::PropertyAssembler.new(@database, alias_table: @alias_table).resolve_references
    @database.finalize!
    @database
  end
end
```

The Builder remains the public entry. Internal seams let each
collaborator be tested independently.

## Acceptance

- [x] `ImportResolver` extracted; tested with synthetic ASTs.
- [x] `PropertyAssembler` extracted; tested with synthetic properties.
- [x] Builder drops below 200 lines.
- [x] All 757 specs pass.

## Dependencies

None. Independent of #26 / #27.
