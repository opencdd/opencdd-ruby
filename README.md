# cdd — Ruby model for the IEC Common Data Dictionary

A pure-Ruby library that models the IEC Common Data Dictionary
(IEC 61360 / CDD ontology), supports power-type semantics where
instances can themselves be used as classes, and imports the Parcel
Excel workbook format (both ParcelMaker `.xlsx` and the legacy
6-file `.xls` export layout) into a navigable in-memory database.

This is the **Ruby core** of the OpenCDD ecosystem. The companion
packages are:

- [opencdd/cdd-models-ts](https://github.com/opencdd/cdd-models-ts) —
  TypeScript port, generated from `PropertyIds::REGISTRY` via
  `rake generate_ts`.
- [opencdd/opencdd.github.io](https://github.com/opencdd/opencdd.github.io) —
  the public browser (Astro, pre-renders all entity pages).

## Installation

Add to your `Gemfile`:

```ruby
gem "cdd", git: "https://github.com/opencdd/opencdd-ruby.git"
```

## Quick start

```ruby
require "cdd"

database = Cdd::Reader.load_database("path/to/iec62683-scraped")
puts database.classes.first.preferred_name
# => "General technical data"
```

## Architecture

```
lib/cdd/
├── cdd.rb                  # top-level autoloads
├── version.rb
├── entity.rb               # base entity + field DSL registry
├── klass.rb, property.rb,  # typed entity subclasses
├── unit.rb, value_list.rb,
├── value_term.rb, relation.rb,
├── view_control.rb
├── database.rb             # in-memory store; finalize! / merge / find
├── effective_properties.rb # cycle-safe walker
├── irdi.rb, property_ids.rb # the SSOT MDC_P### registry
├── validators/             # R01–R14 + Runner
├── parcel/                 # readers (workbook, flat_dir, sharded_dir)
│                            # + Writer (round-trip)
├── exporters/              # Json, Yaml, Mermaid
├── cddal/                  # plain-text canonical format
└── codegen/                # rake generate_ts → cdd-models-ts
```

## Commands

```bash
bundle install
bundle exec rspec                                # full suite
bundle exec rake generate_ts                     # regenerate TS registry
bundle exec rake browser:build[iec62683]          # build JSON for one dict
```

## Project context

Originally part of `opencdd/cdd-data` (data + gem + browser +
editor). Extracted to its own repo per the multi-repo architecture
(see [TODO.astro](https://github.com/opencdd/opencdd.github.io/blob/main/TODO.astro/00-architecture-and-decisions.md)).

License: MIT.
