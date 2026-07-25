---
title: Getting started
description: A 15-minute tutorial — load a dictionary, navigate the entity graph, query powertypes, emit output.
published: 2026-07-25
section: Getting Started
order: 10
---

This guide takes about 15 minutes. By the end you'll know how to load
a CDD dictionary, navigate the entity graph, query powertype
relationships, and emit CDDAL or Parcel output.

## What is CDD?

The **Common Data Dictionary (CDD)** is a four-layer ontology
standardised by IEC 61360 / 62656-1. It's used to publish engineering
dictionaries — product classes, materials, quantities, units — in a
shared, IRDI-addressable form. The canonical public instance is
[`cdd.iec.ch`](https://cdd.iec.ch).

CDD's defining feature is **powertype modelling**: a class declared
`CATEGORICAL_CLASS` has subclasses that ARE themselves classes but
also act as its instances. See [ontology.md](ontology.md) for the
full conceptual walkthrough. For now, just hold this in your head:

> In CDD, an "instance of a categorical class" is another class.
> This is what makes CDD different from UML/RDF/OWL.

## Install

```ruby
# Gemfile
gem "opencdd"
```

```bash
bundle install
```

Requires Ruby ≥ 3.1. The gem ships with these runtime deps: `roo`,
`rubyzip`, `spreadsheet`, `caxlsx`, `csv`.

## Your first database

The fastest path is to parse a CDDAL file. The OceanRunner fixture is
a self-contained 40-entity dictionary that exercises the full
powertype pattern:

```ruby
require "opencdd"

db = Opencdd::Cddal.parse_file("reference-docs/examples/oceanrunner.cddal")
# => #<Opencdd::Database classes=20 properties=19 ...>
```

`Opencdd::Cddal.parse_file` returns an `Opencdd::Database` — the
in-memory store. From here, every operation works the same way,
regardless of which format the data came from.

## Navigating the entity graph

### Finding entities

```ruby
# By IRDI (canonical key)
db.find(Opencdd::IRDI.parse("0112/2///61360_4#AAA001"))

# By short code (most common)
db.find_by_code("AAA001")              # => #<Opencdd::Klass AAA001 "Vehicle">

# By preferred name
db.find_by_name("Boat", type: :class)  # => #<Opencdd::Klass AAA010>
```

### Type-partitioned accessors

```ruby
db.classes        # => [#<Klass AAA001>, #<Klass AAA010>, ...]
db.properties     # => [#<Property AAAP001>, ...]
db.units          # => [#<Unit ...>]
db.value_lists    # => [#<ValueList AAAE001>]
db.value_terms    # => [#<ValueTerm ...>]
db.relations      # => [#<Relation ...>]
db.view_controls  # => [#<ViewControl ...>]
db.entities       # => everything flat
```

### Class hierarchy

```ruby
vehicle = db.find_by_code("AAA001")
vehicle.parent_irdi           # => nil (root)
vehicle.children.map(&:code)  # => ["AAA010", "AAA020", "AAA030", "AAA100"]
vehicle.ancestors             # => [vehicle]  (root)
vehicle.descendants.map(&:code).size  # => 19

boat = db.find_by_code("AAA010")
boat.parent.code              # => "AAA001"
boat.parent.preferred_name    # => "Vehicle"
```

### Properties on a class

```ruby
vehicle.properties_on_class(db).map(&:code)        # declared only
# => ["AAAP001", "AAAP002", "AAAP003"]

vehicle.effective_properties.map(&:code)           # inherited + declared
# => ["AAAP001", "AAAP002", "AAAP003"]

# Walks superclass + is_case_of chains, cycle-safe
transmedium = db.find_by_code("AAA100")
transmedium.effective_properties.map(&:preferred_name).size
# => 14  (3 own + 3 from Vehicle + 3 from Boat + 3 from Car + 2 from Submarine)
```

## The powertype API

This is where CDD gets interesting. A `CATEGORICAL_CLASS` is a
*class whose instances are themselves classes*.

```ruby
engine_type = db.find_by_code("AAA200")
engine_type.powertype?                              # => true

# The powertype instances — EngineType's subclasses that ARE its
# categorical options
engine_type.categorical_instances(db).map(&:code)
# => ["AAA201", "AAA202", "AAA203"]   # SingleDiesel, TwinDiesel, ElectricHybrid

# Database-driven entry point (accepts Klass, IRDI, or code String)
db.instances_of(engine_type).map(&:preferred_name)
# => ["Single Diesel Engine", "Twin Diesel Engine", "Electric Hybrid Engine"]

# Predicate: is this value a valid option for CLASS_REFERENCE(EngineType)?
single_diesel = db.find_by_code("AAA201")
db.valid_class_reference?(engine_type, single_diesel)  # => true

vehicle = db.find_by_code("AAA001")
db.valid_class_reference?(engine_type, vehicle)        # => false
```

This is what `CLASS_REFERENCE(EngineType)` data types enforce at
validation time, and what `sub_class_selection: { TwinDiesel, ... }`
expresses on configured subclasses.

## Multi-format I/O

The same `Database` flows through every format reader and writer.

### From Parcel `.xlsx` (ParcelMaker format)

```ruby
db = Opencdd::Parcel::WorkbookReader
       .new("export_CDD_IEC62683 in ParcelMaker format.xlsx")
       .load_into(Opencdd::Database.new)
db.classes.size  # => ~250
```

### From legacy 6-file `.xls`

```ruby
Opencdd::Parcel::FlatDirReader
  .new("export_CDD_IEC62368 in EXCEL format")
  .load_into(Opencdd::Database.new)
```

### From per-class sharded dirs (harvester output)

```ruby
Opencdd::Parcel::ShardedDirReader
  .new("downloads/iec63213")
  .load_into(Opencdd::Database.new)
```

### Auto-detect from path

```ruby
db = Opencdd::Database.load("any/of/the/above/paths")
```

### To Parcel `.xlsx`

```ruby
Opencdd::Parcel::Writer.new(db).write(
  "out.xlsx",
  parcel_id: "MY_DICT",
  project_id: "MY_PROJECT",
  source_language: "en",
  translation_languages: %w[fr ja],
)
```

### To CDDAL (the plain-text canonical format)

```ruby
File.write("out.cddal", Opencdd::Cddal.serialize(db))
```

### To JSON / YAML / Mermaid

```ruby
File.write("out.json", Opencdd::Exporters::Json.new.to_json(db))
File.write("out.yaml", Opencdd::Exporters::Yaml.new.to_yaml(db))
Opencdd::Exporters::Mermaid.new.to_diagram(db)  # Mermaid markdown
```

## Validation

```ruby
errors = Opencdd::Validator.run(db)
errors.first.rule      # => "R08"
errors.first.entity_irdi.to_s  # => "0112/2///61360_4#AAA001"
errors.first.message   # => "R08: reference \"UNIVERSE\" does not resolve..."

# Rule predicates — usable directly from the editor's live validator
Opencdd::Validator.irdi_well_formed?("AAA001")          # => true
Opencdd::Validator.irdi_well_formed?("garbage")         # => true (IRDI is permissive)
Opencdd::Validator.class_hierarchy_acyclic?(db)         # => true
```

Rules implemented: R01 (IRDI syntax), R02 (code uniqueness), R03 (data
type compliance), R04 (enum membership), R05 (value format), R06
(pattern), R07 (mandatory), R08 (reference resolution), R09 (set
well-formedness), R10 (synonym set), R11 (condition), R12 (data type
expression), R13 (format compatibility), R14 (class hierarchy acyclic),
R15 (composition acyclic), R16 (CLASS_REFERENCE target — uses the
powertype API).

## The CDDAL module system

CDDAL files can cross-reference each other via IRDI, with file
location resolved from a local path OR a URL:

```cddal
import "https://cdd.opencdd.org/dictionaries/rec20-units.cddal"
import "./shared/components.cddal"
import "./engines.cddal" as engines                # qualified
from "./colors.cddal" import { Red, Blue }         # selective

instance MyProduct < MDC_C002 {
  code: AAA999
  superclass: Vehicle
  engine_type: CLASS_REFERENCE(EngineType)
  color: Red
}
```

Cycles are detected. Imports are deduped. Source-location is tracked
end-to-end. See [cddal-syntax.md](cddal-syntax.md).

## Where to go next

- **[ontology.md](ontology.md)** — the four-layer CDD model and
  powertype semantics explained from scratch
- **[cddal-syntax.md](cddal-syntax.md)** — every CDDAL construct with
  examples
- **[parcel-format.md](parcel-format.md)** — the Parcel `.xlsx` sheet
  structure, header layout, and round-trip semantics
- **[architecture.md](architecture.md)** — how the gem is structured
  internally, where to extend it
- **The fixtures** at `reference-docs/examples/oceanrunner.cddal`
  (read it — it's heavily commented and exercises every feature)
