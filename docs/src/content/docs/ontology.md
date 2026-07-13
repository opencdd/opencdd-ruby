---
title: The four-layer CDD ontology
description: CDD's distinguishing concept — powertype modelling — and why CDD is not UML, RDF/OWL, or a typical object model.
---

# The CDD four-layer ontology

CDD (Common Data Dictionary) is an engineering-dictionary ontology
standardised by IEC 61360 / 62656-1. This guide explains its
distinguishing concept — **powertype modelling** — and why CDD is
*not* UML, RDF/OWL, or a typical object model.

If you've used UML or OWL, this guide is for you. If you haven't,
skipping to the worked example at the end is fine.

## The four layers

CDD inherits the four-layer metamodeling architecture from
ISO/IEC 11179, but with a twist.

```
┌──────────────────────────────────────────────────────────────────┐
│ M2  Meta-model    The meta-classes themselves. Fixed set per     │
│ ↓                 IEC 61360:                                      │
│                   MDC_C001 Dictionary                             │
│                   MDC_C002 Class                                  │
│                   MDC_C003 Property                               │
│                   MDC_C004 Supplier                               │
│                   MDC_C005 ValueList (Enumeration)                │
│                   MDC_C006 Datatype                               │
│                   MDC_C007 Document                               │
│                   MDC_C008 Object                                 │
│                   MDC_C009 Unit                                   │
│                   MDC_C010 ValueTerm                              │
│                   MDC_C011 Relation                               │
│                   EXT_C001 ViewControl                            │
│                                                                  │
│                   Modeled by: Opencdd::MetaClass                  │
│                   Lives in: Opencdd::MetaClasses registry         │
├──────────────────────────────────────────────────────────────────┤
│ M1  Model         The dictionary content — instances of M2       │
│ ↓                 meta-classes. This is what authors write.      │
│                                                                  │
│                   AAA001 "Vehicle"           (instance of Class) │
│                   AAAP001 "vehicle length"   (instance of Property)│
│                   UAC001 "metre"             (instance of Unit)   │
│                                                                  │
│                   Modeled by: Opencdd::Entity subclasses         │
│                   Lives in: Opencdd::Database                    │
├──────────────────────────────────────────────────────────────────┤
│ M0  Data          Specific individuals — instances of M1         │
│                   classes. Real-world things.                    │
│                                                                  │
│                   ORCA30-TH-0001 (a specific vehicle, hull #0001)│
│                   SN-12345 (a specific component)                │
│                                                                  │
│                   Often stored as instance data in downstream     │
│                   systems; the gem's Database focuses on M1/M2.   │
└──────────────────────────────────────────────────────────────────┘
```

## The powertype distinction

This is what makes CDD unlike UML/RDF/OWL.

In UML/RDF/OWL:
- Classes are at one level; instances are terminal at the level below.
- An "instance of X" is an object, never another class.

In CDD:
- A class declared `class_type=CATEGORICAL_CLASS` has subclasses that
  are themselves classes, **but are also treated as its instances**.
- This two-level capability lets CDD model *configurable product
  hierarchies*: a categorical class declares the menu; its subclasses
  are the options.

Concretely, in the OceanRunner fixture:

```cddal
instance EngineType < MDC_C002 {
  code: AAA200
  class_type: CATEGORICAL_CLASS
}

instance SingleDieselEngine < MDC_C002 {
  code: AAA201
  superclass: EngineType
  class_type: ITEM_CLASS
}

instance TwinDieselEngine < MDC_C002 {
  code: AAA202
  superclass: EngineType
  class_type: ITEM_CLASS
}

instance ElectricHybridEngine < MDC_C002 {
  code: AAA203
  superclass: EngineType
  class_type: ITEM_CLASS
}
```

Three things are simultaneously true of `SingleDieselEngine`:

1. It is an M1 entity (instance of the `MDC_C002` meta-class).
2. It is a *subclass* of `EngineType` via `superclass: EngineType`.
3. It is an *instance* of `EngineType` in the powertype sense — i.e. it
   is a valid value for any `CLASS_REFERENCE(EngineType)` data type.

Statement (3) is what's unique. You can use `SingleDieselEngine`'s
IRDI as a *value* of a property whose type is `CLASS_REFERENCE(EngineType)`:

```cddal
instance engine_type < MDC_C003 {
  code: AAAP200
  definition_class: OceanRunner
  data_type: CLASS_REFERENCE(EngineType)
}
```

And you can build configured product subclasses that pick specific
categorical instances:

```cddal
instance ORCA30_TwinDiesel_Premium_CarbonBlack < MDC_C002 {
  code: BBB100
  superclass: ORCA30
  sub_class_selection: { TwinDieselEngine, PremiumInterior, CarbonBlackHull }
}
```

## The API in opencdd

The powertype pattern is modeled explicitly:

```ruby
require "opencdd"

db = Opencdd::Cddal.parse_file("reference-docs/examples/oceanrunner.cddal")

engine_type = db.find_by_code("AAA200")
single_diesel = db.find_by_code("AAA201")

# Predicate: is this a categorical (powertype) class?
engine_type.powertype?                            # => true

# What are its instances?
engine_type.categorical_instances(db).map(&:code)
# => ["AAA201", "AAA202", "AAA203"]

# Or from the database side:
db.instances_of(engine_type).map(&:preferred_name)
# => ["Single Diesel Engine", "Twin Diesel Engine", "Electric Hybrid Engine"]

# Validate a CLASS_REFERENCE value
db.valid_class_reference?(engine_type, single_diesel)   # => true
db.valid_class_reference?(engine_type, "AAA001")        # => false (Vehicle isn't an EngineType instance)
```

The R16 validator rule enforces `CLASS_REFERENCE` constraints:

```ruby
errors = Opencdd::Validator.run(db)
errors.select { |e| e.rule == "R16" }
# Any property whose value IRDI isn't a valid powertype instance
# of the CLASS_REFERENCE target appears here.
```

## Categorical class types

CDD defines several `class_type` values; the powertype-relevant ones:

| `class_type`         | Powertype? | Meaning                                       |
|----------------------|:----------:|-----------------------------------------------|
| `ITEM_CLASS`         | no         | A concrete class. Terminal in the powertype tree. |
| `CATEGORICAL_CLASS`  | **yes**    | A powertype: its subclasses are its categorical instances. |
| `VALUE_CLASS`        | varies     | A class describing discrete values.            |
| `MESSAGE_CLASS`      | no         | A class describing a structured message.       |

`Klass#powertype?` is true iff `class_type == CATEGORICAL_CLASS`.

## Comparison to other ontologies

| Feature                          | CDD             | UML             | RDF/OWL         | Plain OOP       |
|----------------------------------|:---------------:|:---------------:|:---------------:|:---------------:|
| Class/instance distinction       | yes             | yes             | yes             | yes             |
| Meta-class layer                 | yes (M2 fixed)  | via stereotypes | via owl:Class   | via `Class`     |
| Instances can be classes         | **yes**         | no              | partial         | no              |
| Inheritance                      | `superclass`    | generalization  | rdfs:subClassOf | `extends`       |
| Multi-parent inheritance         | `is_case_of`    | yes             | yes             | no              |
| Conditional properties           | `CONDITION_DET` | constraints     | owl:Restriction | no              |
| IRDI-addressable                 | **yes**         | no              | no (URI)        | no              |
| Reference to class as value      | `CLASS_REFERENCE` | via metaclasses | via rdfs:Class | via `Class<%gt;` |

The CDD `CLASS_REFERENCE` is the canonical mechanism for "this
property's value is a class, not an instance". In RDF you'd say the
property has range `owl:Class`; in CDD you say it has data type
`CLASS_REFERENCE(EngineType)` and the categorical constraint is
explicit.

## Worked example: OceanRunner

Read [`reference-docs/examples/oceanrunner.cddal`](../reference-docs/examples/oceanrunner.cddal)
alongside this section. It exercises:

- **M2 layer**: the `meta-class MDC_C002 { ... }` declarations register
  which properties classes may carry.
- **M1 base classes**: Vehicle, Boat, Car, Submarine — concrete product types.
- **Multi-parent inheritance**: TransmediumVehicle combines Boat + Car +
  Submarine via `is_case_of`.
- **Three categorical classes**: EngineType, InteriorPackage, HullFinish —
  each with two or three item-class options.
- **CLASS_REFERENCE properties**: `engine_type`, `interior_package`,
  `hull_finish` on the OceanRunner brand.
- **Configured product subclass**: ORCA30_TwinDiesel_Premium_CarbonBlack
  uses `sub_class_selection` to pin three categorical options.
- **M0 individual**: ORCA30_UNIT_0001, a specific serial-numbered unit.

This single fixture is the best way to internalise CDD's
distinguishing capability. Run it through `Opencdd::Cddal.parse_file`
and explore the result.

## Further reading

- IEC 61360-1 (terms and definitions) — see `reference-docs/normative/IEC61360-1_ED4.md`
- IEC 61360-6 (the ontology) — see `reference-docs/normative/IEC61360-6_ED1.md`
- IEC 62656-1 (the Parcel format) — see `reference-docs/standards/IEC62656-1 FDIS ED1.doc`
- ParcelMaker manual — see `reference-docs/normative/ParcelMaker_Manual_v5.0.0.md`
