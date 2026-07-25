---
title: Validator rules
description: The 16 rules enforced by Opencdd::Validator, with examples.
published: 2026-07-25
section: Reference
order: 90
---

`Opencdd::Validator.run(database)` returns an Array of
`ValidationError` records. Each error carries the rule ID, the
offending entity, the cell value, and a human-readable message.

```ruby
errors = Opencdd::Validator.run(db)
errors.first.rule      # => "R08"
errors.first.entity_irdi.to_s  # => "0112/2///61360_4#AAA001"
errors.first.message   # => "R08: reference \"UNIVERSE\" does not resolve..."
```

## Rule catalogue

### R01 — IRDI syntax

Every `Code` cell (column A) must parse as an IRDI per
ISO/IEC 11179-6. Three forms accepted: full, short, commented.

```ruby
Opencdd::Validator.irdi_well_formed?("AAA001")   # => true
Opencdd::Validator.irdi_well_formed?("")         # => false
```

### R02 — Code uniqueness

Codes are `#REQUIREMENT = KEY`. Within a sheet, codes must be unique.

### R03 — Data type compliance

Each cell value must parse per its column's declared data type
(`#DATATYPE` row).

| Data type              | Predicate                                  |
|------------------------|--------------------------------------------|
| `BOOLEAN_TYPE`         | value ∈ {`true`, `false`}                  |
| `STRING_TYPE`          | any string                                 |
| `REAL_TYPE`            | parseable as Float                         |
| `RATIONAL_TYPE`        | parseable as Rational                      |
| `IRDI_STRING_TYPE`     | parses as IRDI (R01)                       |
| `DATE_TIME_TYPE`       | ISO 8601                                   |
| `ENUM_*_TYPE`          | member of the value list (R04)             |
| `AGGREGATE`            | recursively valid per element type         |

### R04 — Enumeration membership

For `ENUM_*_TYPE` columns, the value must be a member of the value
list referenced by the property's `MDC_P043`.

### R05 — Value format compliance

Value must match the IEC 61360-2 value-format token in the
`#VALUE_FORMAT` row.

```
NR1 S..5    → 5-digit signed integer
NR2 S..7.3  → 7-digit + 3-decimal signed
NR3 S..7.7  → real with 7 sig digits
M..255      → string up to 255 chars
```

### R06 — Pattern constraint

Value must match the PCRE regex in the `#PATTERN` row.

```ruby
Opencdd::Validator.pattern_valid?("abc123", "^\\w+$")  # => true
```

### R07 — Mandatory field non-empty

Cells in `MAND` or `KEY` columns must not be empty.

### R08 — Cross-reference integrity

Every IRDI reference must resolve to an entity in the active
database. Applies to single references and to `{a,b,c}` sets.

```ruby
Opencdd::Validator.run(db).select { |e| e.rule == "R08" }.first.message
# => "R08: reference \"UNIVERSE\" does not resolve in this database"
```

### R09 — Set well-formedness

`{a,b,...}` and `{(a,b),...}` literals must start with `{`, end with
`}`, have comma-separated elements, and balance parens within tuples.

### R10 — Synonymous-name well-formedness

`MDC_P004_2` cells must use the `{(name,lang),(name,lang),...}` form.

### R11 — Condition well-formedness

Conditions must be either a `{(IRDI, value),...}` list or a
`<property_code> == <value>` predicate expression.

### R12 — Data type expression well-formedness

`MDC_P022` cells must parse as a data type expression:
- Primitive (`REAL_TYPE`, `STRING_TYPE`, ...)
- Enum form (`ENUM_STRING_TYPE(<value-list-IRDI>)`)
- Aggregate (`<container>(<element-type>, count)`, up to depth 3)

### R13 — Value format matches data type

`#VALUE_FORMAT` must be compatible with `#DATATYPE`.

### R14 — Class hierarchy acyclic

A class's `MDC_P010` (superclass) chain must not form a cycle.

```ruby
Opencdd::Validator.class_hierarchy_acyclic?(db)  # => true
```

### R15 — Composition hierarchy acyclic

Applicable properties (`MDC_P014`) form a composition graph that must
be acyclic. Uses `Opencdd::EffectiveProperties` for traversal.

### R16 — CLASS_REFERENCE target validation

Added in audit round 2 ([see A20](https://github.com/opencdd/opencdd-ruby/blob/main/TODO.impl/16-audit-findings.md)).

When a property's data type is `CLASS_REFERENCE(CategoricalClass)`,
the value IRDI must resolve to an entity that is a valid powertype
instance of `CategoricalClass`. This rule closes the loop on CDD's
powertype semantics — R08 only checks IRDI resolution, not the
categorical constraint.

```ruby
# EngineType is CATEGORICAL_CLASS. Its valid instances are
# SingleDiesel, TwinDiesel, ElectricHybrid.
prop.data_type  # => "CLASS_REFERENCE(EngineType)"

# Valid value
Opencdd::Validator.run(db).select { |e| e.rule == "R16" }
# => [] (empty when all values are valid powertype instances)
```

## Composite runner

```ruby
errors = Opencdd::Validator.run(database)
errors.first.entity_irdi.to_s
errors.first.message
```

The composite walks every entity × every property × every applicable
rule. Returns a flat list the UI can render as clickable error
locations.

## Per-rule predicates

Each rule also exposes a predicate for reuse in the OpenCDD Editor's
live validator (TypeScript port):

```ruby
Opencdd::Validator.irdi_well_formed?(value)              # R01
Opencdd::Validator.mandatory_present?(value)             # R07
Opencdd::Validator.pattern_valid?(value, pattern)        # R06
Opencdd::Validator.class_hierarchy_acyclic?(database)    # R14
```

## Adding a rule

1. Subclass `Opencdd::Validator::Rule` in
   `lib/opencdd/validator/<name>_rule.rb`.
2. Implement `id`, `applies?(context)`, `call(value, context)`, and
   `message(value, context)`.
3. Register in `Opencdd::Validator::Runner::RULES`.
4. Add autoload to `lib/opencdd/validator.rb`.
5. Write specs in `spec/validator/<name>_rule_spec.rb`.

The runner picks up the new rule automatically — no switch to update.
