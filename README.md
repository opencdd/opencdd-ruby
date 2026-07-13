# opencdd — Ruby model for the IEC Common Data Dictionary

[![CI](https://github.com/opencdd/opencdd-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/opencdd/opencdd-ruby/actions/workflows/ci.yml)
[![Gem](https://img.shields.io/gem/v/opencdd.svg)](https://rubygems.org/gems/opencdd)

**opencdd** is a pure-Ruby library for reading, writing, validating, and
navigating the IEC Common Data Dictionary (CDD) — the ISO/IEC 61360 / 62656-1
ontology used by IEC CDD at `cdd.iec.ch`, by ParcelMaker, and by downstream
engineering and BOM tooling.

It is the Ruby core of the OpenCDD ecosystem:

- [`opencdd/cdd-models-ts`](https://github.com/opencdd/cdd-models-ts) — TypeScript port (model layer)
- [`opencdd/editor`](https://github.com/opencdd/editor) — Browser-based CDD editor
- [`opencdd/opencdd.github.io`](https://github.com/opencdd/opencdd.github.io) — Static-site dictionary browser
- [`opencdd/cddal-spec`](https://github.com/opencdd/cddal-spec) — The CDDAL format specification

---

## Why CDD? Why this gem?

CDD is a **four-layer ontology** standardised by IEC/TC 184/SC 4/JWG 24 and
IEC/SC 3D. It models engineering dictionaries (components, materials,
quantities, units) with one distinctive capability that separates it from
UML, RDF/OWL, and typical object models:

> **A class declared `CATEGORICAL_CLASS` at the model layer has subclasses
> that are themselves classes, but are also treated as instances of the
> categorical class.** This is called *powertype modelling*.

In UML/RDF, an "instance" is a terminal object. In CDD, an "instance" of a
categorical class is *another class* that can be further specialised. This
two-level capability lets CDD express configurable product hierarchies
("this product line offers engine options {SingleDiesel, TwinDiesel,
ElectricHybrid}") without leaving the type system.

`opencdd` preserves this capability as a first-class concept — see
`Klass#powertype?`, `Database#instances_of`, and the
[ontology guide](docs/ontology.md).

---

## Installation

Add to your `Gemfile`:

```ruby
gem "opencdd"
```

Or install from source:

```bash
git clone https://github.com/opencdd/opencdd-ruby.git
cd opencdd-ruby
bundle install
bundle exec rake build
gem install pkg/opencdd-*.gem
```

Requires Ruby ≥ 3.1.

---

## Quick start

```ruby
require "opencdd"

# Load a Parcel-format dictionary (sharded per-class layout)
db = Opencdd::Database.load("downloads/iec63213")

# Find a class and walk its hierarchy
vehicle = db.find_by_code("AAA001")
puts vehicle.preferred_name                          # => "Vehicle"
puts vehicle.children.map(&:code)                    # => ["AAA010", "AAA020", "AAA030", ...]
puts vehicle.effective_properties.map(&:code)        # inherited + declared properties

# Powertype API: what configuration options does EngineType offer?
engine_type = db.find_by_code("AAA200")
engine_type.powertype?                               # => true
db.instances_of(engine_type).map(&:preferred_name)
# => ["Single Diesel Engine", "Twin Diesel Engine", "Electric Hybrid Engine"]
```

### Parse CDDAL (the plain-text canonical format)

```ruby
db = Opencdd::Cddal.parse_file("path/to/dictionary.cddal")
# => Opencdd::Database populated with classes, properties, units, ...
```

### Read a Parcel `.xlsx` workbook

```ruby
db = Opencdd::Parcel::WorkbookReader
       .new("export_CDD_IEC62683 in ParcelMaker format.xlsx")
       .load_into(Opencdd::Database.new)
db.classes.size   # => 250+
```

### Round-trip CDDAL → Parcel → CDDAL

```ruby
db    = Opencdd::Cddal.parse_file("oceanrunner.cddal")
xlsx  = Tempfile.new(["out", ".xlsx"]).path
Opencdd::Parcel::Writer.new(db).write(xlsx, parcel_id: "OCEANRUNNER")

db2   = Opencdd::Database.load(xlsx)
db.semantically_equal?(db2)                          # => true
```

### Validate

```ruby
errors = Opencdd::Validator.run(db)
errors.first.message  # => "R08: reference \"UNIVERSE\" does not resolve..."
errors.first.rule     # => "R08"
```

---

## What you can do with this gem

| Task | Class / method |
|------|---------------|
| Read Parcel `.xlsx` (ParcelMaker 5.2.1 layout) | `Opencdd::Parcel::WorkbookReader` |
| Read legacy 6-file `.xls` layout | `Opencdd::Parcel::FlatDirReader` |
| Read per-class sharded `.xls` (harvester output) | `Opencdd::Parcel::ShardedDirReader` |
| Write Parcel `.xlsx` | `Opencdd::Parcel::Writer` |
| Parse / serialize CDDAL (plain-text format) | `Opencdd::Cddal.parse`, `Opencdd::Cddal.serialize` |
| Split / aggregate dictionaries | `Opencdd::Parcel.split`, `Opencdd::Parcel.aggregate` |
| Validate against IEC 61360 rules | `Opencdd::Validator.run` (R01–R16) |
| Export to JSON / YAML / Mermaid | `Opencdd::Exporters::{Json,Yaml,Mermaid}` |
| Powertype queries | `Klass#powertype?`, `Database#instances_of`, `Database#valid_class_reference?` |

---

## The four-layer CDD ontology

CDD is layered per IEC 61360 §5:

```
M2  Meta-model        The meta-classes: Class, Property, Unit, ValueList,
                     ValueTerm, Relation, ViewControl.
                     Modeled as Opencdd::MetaClass instances.
                     Fixed set per the standard.

M1  Model            The dictionary content: AAA001 "Vehicle",
                     AAAP001 "vehicle length", etc. Instances of M2
                     meta-classes. Modeled as Opencdd::Entity
                     subclasses (Klass, Property, Unit, ...).

M0  Data             Real-world individuals: serial-numbered units,
                     specific product configurations. Instances of
                     M1 classes.
```

**The powertype distinction**: at M1, a class declared
`class_type=CATEGORICAL_CLASS` has subclasses that are *also* its
instances in the categorical sense. Used for:

- `CLASS_REFERENCE(EngineType)` — a property value constrained to one of
  EngineType's categorical instances
- `sub_class_selection: { TwinDiesel, Premium, CarbonBlack }` — a
  configured subclass nailing down categorical options

See [`docs/ontology.md`](docs/ontology.md) for the full walkthrough.

---

## Architecture

```
lib/opencdd/
├── opencdd.rb              # canonical entry (autoload tree)
├── cdd.rb                  # back-compat shim: require "opencdd"
├── version.rb
│
├── entity.rb               # base entity + field DSL
├── klass.rb                # class entity + powertype API
├── property.rb, unit.rb, value_list.rb, value_term.rb,
├── relation.rb, view_control.rb
│
├── meta_class.rb           # M2 meta-classes (SSOT for type/sheet mapping)
├── property_ids.rb         # SSOT for MDC_P### identifiers
├── alias_table.rb          # alias → property ID resolution
├── irdi.rb                 # IRDI parsing (3 forms)
├── class_type.rb, data_type.rb, value_format.rb,
├── condition.rb, property_data_element_type.rb,
├── relation_type.rb, languages.rb
│
├── database.rb             # in-memory store; finalize! / merge / find
├── effective_properties.rb # cycle-safe walker
├── class_tree.rb, composition_tree.rb, relation_tree.rb
│
├── parcel/                 # IEC 62656-1 Parcel format
│   ├── workbook_reader.rb, flat_dir_reader.rb, sharded_dir_reader.rb
│   ├── writer.rb, csv_writer.rb, csv_reader.rb
│   ├── sheet.rb, sheet_schema.rb, sheet_emitter.rb
│   ├── metadata.rb, workbook.rb, selector.rb, referenced_irdis.rb
│
├── cddal/                  # plain-text canonical format
│   ├── lexer.rb, cddal.y, generated_parser.rb, parser.rb
│   ├── ast.rb, builder.rb, serializer.rb
│   ├── resolver.rb         # module/import path/URL resolution
│   └── fetcher/            # pluggable URL fetcher (NetHttp, InMemory)
│
├── validator/              # R01–R16 rules + Runner
│   ├── irdi_rule.rb, uniqueness_rule.rb, mandatory_rule.rb,
│   ├── type_rule.rb, enum_rule.rb, format_rule.rb, pattern_rule.rb,
│   ├── reference_rule.rb, set_rule.rb, synonym_rule.rb,
│   ├── condition_rule.rb, data_type_rule.rb, hierarchy_rule.rb,
│   └── class_reference_rule.rb  # R16 — uses powertype API
│
├── exporters/              # json.rb, yaml.rb, mermaid.rb
├── codegen/                # ts.rb — generates PropertyIds.generated.ts
└── entity/
    ├── field_registry.rb   # DSL: field :name, "MDC_P###"
    ├── field_reader.rb     # instance_exec dispatch (no send-to-private)
    └── version_history.rb
```

### Principles followed

- **OCP**: adding an entity type / validator rule / exporter = adding a
  class, not editing a switch.
- **DRY**: one source of truth per concept. `MetaClasses` owns the
  type→class→sheet-type mapping; `PropertyIds::REGISTRY` owns every
  property ID; no raw `"MDC_P###"` literals outside the registry files
  (enforced by `bin/lint-no-raw-mdc`).
- **MECE**: each concern lives in exactly one place. Parcel format
  readers don't know about CDDAL; the validator doesn't know about
  formats; the model doesn't know about Parcel.
- **Encapsulation**: no `send` to private methods (enforced by
  `spec/code_quality_spec.rb`); entity state mutated only through named
  mutators.
- **`autoload`, not `require_relative`**: load paths declared in the
  immediate parent namespace file (enforced by `spec/code_quality_spec.rb`).

---

## Commands

```bash
bundle install                         # install dependencies
bundle exec rake spec                  # full spec suite (~700 examples)
bundle exec rake spec:data             # data-fixture specs only (faster)
bundle exec rake build                 # build pkg/opencdd-*.gem
bundle exec rake cddal:regen           # regenerate racc parser from cddal.y
bundle exec rake cddal:check_regen     # fail CI if parser is stale
bundle exec rake lint:registry         # forbid raw MDC_P### outside registry
bundle exec rake generate_ts           # regenerate cdd-models-ts files
```

---

## Documentation

**Live docs site: <https://opencdd.github.io/opencdd-ruby/>**

The site is built with [Astro Starlight](https://starlight.astro.build/)
from the Markdown sources in [`docs/src/content/docs/`](docs/src/content/docs/).
It auto-deploys via GitHub Actions on every push to `main` that touches
`docs/`. Source files are also browseable on GitHub.

- **[Getting started](docs/src/content/docs/getting-started.md)** — 15-minute tutorial
- **[The four-layer ontology](docs/src/content/docs/ontology.md)** — CDD's powertype distinction
- **[CDDAL syntax](docs/src/content/docs/cddal-syntax.md)** — authoring plain-text CDD
- **[Parcel format](docs/src/content/docs/parcel-format.md)** — reading and writing Parcel `.xlsx`
- **[Architecture](docs/src/content/docs/architecture.md)** — gem internals and extension points
- **[Feature audit](docs/src/content/docs/reference/features.md)** — every feature, its status, and where to find it
- **[API reference](docs/src/content/docs/reference/api.md)** — key classes and methods
- **[Validator rules](docs/src/content/docs/reference/validator-rules.md)** — R01–R16 catalogue
- **[TODO.impl/](TODO.impl/)** — engineering plans, audit findings, open questions

## Examples

- [`reference-docs/examples/oceanrunner.cddal`](reference-docs/examples/oceanrunner.cddal) — the canonical powertype demo (40 entities, 20 classes)
- [`reference-docs/202003-kagoshima-iec-def-sample.cddal`](reference-docs/202003-kagoshima-iec-def-sample.cddal) — minimal bare-`instance` form

## Standards background

- **IEC 61360-1** — Terms and definitions
- **IEC 61360-2** — Data specification
- **IEC 61360-6** — Common Data Dictionary ontology
- **IEC 62656-1** — Parcel (Excel) format for CDD content
- **ISO/IEC 11179-6** — IRDI (registration data identifier)

## License

MIT. See [`LICENSE`](LICENSE).

## Contributing

PRs welcome. Please:

1. Open an issue first for non-trivial changes.
2. Follow the principles in [`CLAUDE.md`](CLAUDE.md) and
   [`docs/architecture.md`](docs/architecture.md).
3. Add specs for any new behavior — the `code_quality_spec.rb` enforces
   the architectural rules (no `send` to private, no `require_relative`,
   no `instance_variable_set`, etc.).
4. Do not add AI-attribution trailers to commit messages.
