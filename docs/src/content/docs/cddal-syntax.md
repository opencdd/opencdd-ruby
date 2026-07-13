---
title: CDDAL syntax guide
description: The plain-text canonical format for CDD content — authorable, reviewable, version-controllable, round-trip stable against Parcel.
---

# CDDAL syntax guide

CDDAL (CDD Authoring Language, pronounced "coddle") is the plain-text
canonical format for CDD content. It is:

- **Authorable** in any text editor.
- **Reviewable** in standard code-review workflows.
- **Version-controllable** — line-oriented, meaningful diffs.
- **Round-trip stable** against the Parcel Excel format.

CDDAL and Parcel are information-equivalent: anything expressible in
one is expressible in the other. CDDAL is the on-disk canonical form;
Parcel is the interchange form.

This guide covers the language as implemented by `opencdd`. For the
normative specification, see the
[`cddal-spec`](https://github.com/opencdd/cddal-spec) repository.

## Hello, CDDAL

```cddal
# A one-class dictionary
meta-class MDC_C002 {
  code
  preferred_name
  class_type
}

instance Vehicle < MDC_C002 {
  code: AAA001
  preferred_name.en: "Vehicle"
  class_type: ITEM_CLASS
}
```

Parse it:

```ruby
db = Opencdd::Cddal.parse(source)
db.find_by_code("AAA001").preferred_name  # => "Vehicle"
```

## Lexical structure

- **Whitespace** (space, tab, newline) is insignificant.
- **Comments** run from `#` to end of line.
- **Identifiers** match `[A-Za-z_][A-Za-z0-9_]*`.
- **IRDIs** are pattern-recognised (contain `/` or `#`).
- **String literals** are JSON double-quoted with JSON escapes.
- **Numbers** follow JSON number grammar.
- **Dates** follow ISO 8601 `YYYY-MM-DD`.
- **Booleans** are `true` and `false`.

`as`, `from`, `import`, `instance`, `alias`, `meta-class`, `true`,
`false`, `null` are reserved *in the positions where they introduce a
declaration*. They remain valid identifier values elsewhere — e.g.
`short_name.en: as` for attosecond.

## Declarations

A CDDAL document is a sequence of declarations. Four kinds:

### `meta-class` — declares which properties a meta-class allows

```cddal
meta-class MDC_C002 {
  code
  preferred_name
  superclass
  class_type
  applicable_properties
  is_case_of
}
```

Multiple `meta-class` declarations for the same IRDI merge by union.
Usually you don't write these — the runtime provides defaults.

### `instance` — declares an entity

```cddal
instance Vehicle < MDC_C002 {
  code: AAA001
  preferred_name.en: "Vehicle"
  preferred_name.fr: "Véhicule"
  definition.en: "device that transports people or goods"
  superclass: UNIVERSE
  class_type: ITEM_CLASS
  applicable_properties: { vehicle_length, vehicle_weight }
}
```

Form: `instance [name] < meta-class-ref { assignments }`.

- **`name`** is optional. If present, it's the symbolic name other
  declarations use to refer to this instance.
- **`meta-class-ref`** is the IRDI of the meta-class
  (`MDC_C002` for Class, `MDC_C003` for Property, etc.) or its symbolic name.
- **`assignments`** is a list of property assignments.

Anonymous form (no `<`):

```cddal
instance MDC_C002 {
  code: AAA001
  preferred_name.en: "Vehicle"
}
```

is equivalent — useful when you want to omit the meta-class reference
and let the runtime infer it from context.

### `alias` — binds a symbolic name to a property ID

```cddal
alias code:                MDC_P001_5
alias preferred_name:      MDC_P004
alias superclass:          MDC_P010
alias data_type:           MDC_P022
alias condition:           MDC_P028
```

After declaration, both the alias and the underlying property ID work
interchangeably. The runtime provides built-in aliases; documents can
override.

### `import` — pulls in another CDDAL file

```cddal
import "https://cdd.opencdd.org/dictionaries/rec20-units.cddal"
import "./shared/components.cddal"
import "./engines.cddal" as engines
from "./colors.cddal" import { Red, Blue, Green as G }
```

See the **Module system** section below.

## Property assignments

Form: `<identifier-or-alias>[:.<language-tag>]: <value>`

```cddal
preferred_name.en: "Vehicle"          # language-tagged (English)
preferred_name.fr: "Véhicule"         # language-tagged (French)
superclass: Vehicle                    # symbolic reference
code: AAA001                           # short code
data_type: REAL_TYPE                   # type identifier
applicable_properties: { vehicle_length, vehicle_weight }
condition: operating_mode == surface_water
```

Language tags conform to RFC 5646 (`en`, `fr`, `ja`, `zh-Hans`, etc.).

If a property is assigned multiple times in the same instance:
- For language-tagged assignments: each language contributes one entry.
- For non-language-tagged assignments: the last wins.

## Values

### Literals

```cddal
length: 9.5                            # number
unit_sign: "m"                         # string
manufacturing_date: 2026-06-23         # date
is_amphibious: true                    # boolean
notes: null                            # null
```

### Identifier references

Three equivalent forms for references:

```cddal
superclass: Vehicle                    # by symbolic name
superclass: AAA001                     # by short code
superclass: 0112/2///61360_4#AAA001    # by full IRDI
```

Resolution order: full IRDI → symbolic name → code.

### Sets

Comma-separated, brace-enclosed, unordered:

```cddal
applicable_properties: { vehicle_length, vehicle_weight, vehicle_capacity }
is_case_of: { Boat, Car, Submarine }
imported_properties: { Boat.hull_length, Car.engine_power }
```

The `Class.property` form qualifies a property reference with its
owning class — required when importing a property declared on a class
other than the immediate `is_case_of` target.

### Class references (data type expressions)

```cddal
data_type: CLASS_REFERENCE(EngineType)
data_type: ENUM_STRING_TYPE(vehicle_mode_enum)
data_type: INT_TYPE
data_type: REAL_TYPE
data_type: LIST(REAL_TYPE, 3)
```

These appear as values of the `data_type` (`MDC_P022`) property on
Property entities. The argument of `CLASS_REFERENCE(...)` and
`ENUM_*_TYPE(...)` is an identifier reference resolved against the
document's symbol table.

### Conditions

A condition appears on a Property whose `property_data_element_type` is
`CONDITION_DET`:

```cddal
condition: operating_mode == surface_water
condition: vehicle_kind != "submarine"
condition: operating_mode == { surface_water, underwater }
```

Supported operators: `==` and `!=`. Right-hand side can be a literal,
identifier, or set.

## Module system (split-file format)

CDDAL files can cross-reference each other. Three import forms:

### Bare — textual inclusion

```cddal
import "./base/vehicles.cddal"
```

Every named declaration from the target becomes accessible by its
symbolic name in the importing document.

### Qualified — accessed via prefix

```cddal
import "./base/units.cddal" as units

instance MyVehicle < MDC_C002 {
  length_unit: units.Metre
}
```

The target's names are accessible as `<qualifier>.<name>`.

### Selective — pick specific names

```cddal
from "./base/vehicles.cddal" import { Vehicle, Boat }
from "./base/vehicles.cddal" import { Vehicle as V, Boat as B }
```

Only the listed names are pulled in. Optional `as` clause renames.

### Resolution rules

The resolver tries, in order:

1. **URL** (`http://`, `https://`, `file://`) — fetched via the
   configured `Fetcher` (default: `Net::HTTP` with on-disk cache).
2. **Absolute filesystem path**.
3. **Relative path** (starts with `./` or `../`) — resolved against
   the importing file's directory.
4. **Bare name** — searched in the resolver's `search_path`, then
   `base_path`.

Unreachable URLs and missing paths emit a warning and skip in
non-strict mode (default); raise `Opencdd::Cddal::ImportError` in
strict mode.

### Cycle detection

Circular imports are hard errors:

```ruby
Opencdd::Cddal.parse('import "./a.cddal"', source_file: "main.cddal")
# If a.cddal imports b.cddal and b.cddal imports a.cddal:
# => Opencdd::Cddal::ImportError: circular CDDAL import detected: a.cddal → b.cddal → a.cddal
```

### Custom fetcher

For tests, sandboxed environments, or custom URL schemes:

```ruby
fetcher = Opencdd::Cddal::Fetcher::InMemory.new(
  "https://example.test/dict.cddal" => File.read("fixtures/dict.cddal"),
)
resolver = Opencdd::Cddal::Resolver.new(fetcher: fetcher)
db = Opencdd::Cddal.parse(source, resolver: resolver)
```

For offline-by-default (e.g. CI):

```ruby
fetcher = Opencdd::Cddal::Fetcher::NetHttp.new(offline: true)
```

## Source location tracking

Every entity created from CDDAL carries a `source_location`:

```ruby
entity = db.find_by_code("AAA001")
entity.source_location.file  # => "/path/to/file.cddal"
entity.source_location.line  # => 42
```

Used by the validator to render clickable error locations.

## Round-trip stability

```ruby
db1 = Opencdd::Cddal.parse_file("oceanrunner.cddal")
text = Opencdd::Cddal.serialize(db1)
db2 = Opencdd::Cddal.parse(text)
db1.semantically_equal?(db2)  # => true
```

The serializer produces deterministic, stable output:
- Aliases first, alphabetically
- Meta-class declarations in registry order
- Instances in depth-first superclass-tree traversal, then by code
- Multilingual properties emit one line per language

## Common patterns

### Authoring a new dictionary

```cddal
# 1. Aliases (optional — built-ins cover the basics)
alias code: MDC_P001_5
alias preferred_name: MDC_P004

# 2. Meta-class declarations (optional — runtime provides defaults)
meta-class MDC_C002 {
  code preferred_name superclass class_type applicable_properties
}

# 3. Instance declarations (the meat)
instance Vehicle < MDC_C002 {
  code: AAA001
  preferred_name.en: "Vehicle"
  superclass: UNIVERSE
  class_type: ITEM_CLASS
  applicable_properties: { vehicle_length }
}

instance vehicle_length < MDC_C003 {
  code: AAAP001
  preferred_name.en: "vehicle length"
  definition_class: Vehicle
  data_type: REAL_TYPE
  unit: metre
}

# 4. Comments documenting intent and provenance
```

### Mixing with Parcel

```ruby
# Author in CDDAL, ship as Parcel xlsx
db = Opencdd::Cddal.parse_file("oceanrunner.cddal")
Opencdd::Parcel::Writer.new(db).write("oceanrunner.xlsx", parcel_id: "OCEAN")

# Receive Parcel, edit in CDDAL, ship back
db = Opencdd::Database.load("oceanrunner.xlsx")
File.write("oceanrunner-edited.cddal", Opencdd::Cddal.serialize(db))
```

The two representations are information-equivalent for every entity
and property defined by IEC 61360-1.

## Further reading

- [Normative CDDAL specification](https://github.com/opencdd/cddal-spec)
- [OceanRunner worked example](../reference-docs/examples/oceanrunner.cddal)
- [Kagoshima bare-instance example](../reference-docs/202003-kagoshima-iec-def-sample.cddal)
- [Parcel format guide](parcel-format.md)
