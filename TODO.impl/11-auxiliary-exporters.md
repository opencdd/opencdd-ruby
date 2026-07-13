# Plan 11 — Auxiliary exporters (JSON / YAML / Mermaid)

## Why

The Parcel and CDDAL formats cover the canonical exchange surface. Three
auxiliary exporters ease human review and integration with external
tooling:

- **JSON** — programmatic access for downstream scripts and the editor's
  data pipeline.
- **YAML** — diff-friendly export for documentation and review.
- **Mermaid** — class-hierarchy diagrams for README files and PR reviews.

All three already exist in `lib/cdd/exporters/*.rb`. This plan locks
their public API and ensures they share a common entity-payload helper.

## Scope

- `Cdd::Exporters::Json` — `Database` → JSON string / file.
- `Cdd::Exporters::Yaml` — `Database` → YAML string / file.
- `Cdd::Exporters::Mermaid` — `Database` → Mermaid class-diagram markdown.
- Shared `entity_payload` helper.
- `Cdd::Exporters` namespace file.

Not in scope: Parcel writer (plan 06), CDDAL serializer (plan 08),
CSV writer (plan 06 — Parcel-specific).

## Approach

### Common payload shape

All three exporters use the same per-entity payload, built by
`Cdd::Exporters.entity_payload(entity, database:)`:

```ruby
{
  irdi: entity.irdi.to_s,
  code: entity.code,
  type: entity.type,                  # :class, :property, ...
  meta_class_irdi: entity.meta_class_irdi.to_s,
  source_location: { file: ..., line: ... },
  properties: {
    "MDC_P001_5" => "AAA001",
    "MDC_P004" => { "en" => "Vehicle", "fr" => "Véhicule" },
    "MDC_P010" => "UNIVERSE",
    "MDC_P014" => ["AAAP001", "AAAP002"],
    ...
  },
}
```

Multilingual values are emitted as `{lang => text}`. Set-of-refs values
are emitted as arrays. Scalar values as primitives. This shape is the
canonical "JSON view" of an entity.

### JSON exporter (lib/cdd/exporters/json.rb)

```ruby
Cdd::Exporters::Json.new(database).to_json(pretty: true)
Cdd::Exporters::Json.new(database).to_file(path, pretty: true)
```

Options:
- `pretty:` — default `true` (2-space indent).
- `compact:` — emits single-line JSON, no whitespace. For machine
  consumers.
- `include_raw:` — if true, includes the raw `properties` hash
  alongside typed fields. Default false.

`compact` must **not** strip empty arrays (Ruby `Hash#compact` parity —
preserves schema).

### YAML exporter (lib/cdd/exporters/yaml.rb)

```ruby
Cdd::Exporters::Yaml.new(database).to_yaml
Cdd::Exporters::Yaml.new(database).to_file(path)
```

Uses Ruby's stdlib `Psych`. Output is deterministic: keys sorted,
entities emitted in canonical order (same as plan 08's CDDAL ordering —
superclass-tree DFS then by code).

### Mermaid exporter (lib/cdd/exporters/mermaid.rb)

```ruby
Cdd::Exporters::Mermaid.new(database).to_diagram
Cdd::Exporters::Mermaid.new(database).class_diagram(root: vehicle_irdi)
```

Emits a Mermaid `classDiagram` block. Each class becomes a Mermaid
class node; superclass relationships become `Klass <|-- Parent` arrows;
`is_case_of` becomes `..|>` (dashed) arrows. Properties listed inside
the class block (just the names, not values — keeps diagrams readable).

Optional `root:` filter limits the diagram to a subtree — useful for
large dictionaries where the full diagram is unusable.

### Namespace (lib/cdd/exporters.rb)

```ruby
module Cdd::Exporters
  autoload :Json,    "cdd/exporters/json"
  autoload :Yaml,    "cdd/exporters/yaml"
  autoload :Mermaid, "cdd/exporters/mermaid"

  module_function

  def entity_payload(entity, database:)
    # shared helper
  end
end
```

### No hand-rolled serialization on model classes

Per plan 01, exporters are service classes. `Cdd::Entity` has no
`to_json` / `to_yaml` method. The exporter reads typed accessors and
the raw `properties` hash and constructs the payload itself.

## Acceptance criteria

- [x] `Json.new(db).to_json` re-parsed equals the same Ruby structure
      (round-trip stable).
- [x] `Yaml.new(db).to_yaml` deterministic across runs (same db → same
      bytes).
- [x] `Mermaid.new(db).class_diagram(root: ...)` produces valid Mermaid
      that renders on GitHub.
- [x] Shared `entity_payload` used by all three.
- [x] Empty arrays preserved in `compact` mode.
- [x] No `to_json` / `to_yaml` / `to_h` instance method on any model
      class.
- [x] `spec/exporters_spec.rb` green.

## Dependencies

- **Plan 03** — entities (typed accessors).
- **Plan 05** — Database (entity enumeration).

## Open questions

- **Q1.** Should we offer a streaming JSON emitter for very large
  databases (>100k entities)? **Recommendation:** defer — current
  fixture largest is 11k entities (IEC 61987); standard `JSON.generate`
  is fast enough.
- **Q2.** Should the Mermaid exporter optionally include property
  values? **Recommendation:** no by default (visual noise); add a
  `verbose: true` flag in a follow-up.
