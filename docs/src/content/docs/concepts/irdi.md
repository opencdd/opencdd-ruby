---
title: IRDI identifiers
description: International Registration Data Identifiers — the canonical keys for every CDD entity.
published: 2026-07-25
section: Concepts
order: 30
---

The **IRDI** (International Registration Data Identifier) is the
canonical key for every CDD entity. Defined by ISO/IEC 11179-6, it
gives every class, property, unit, value list, value term, and
relation a globally unique, supplier-qualified identifier.

## Three forms

| Form      | Example                              | When used                       |
|-----------|--------------------------------------|---------------------------------|
| Full      | `0112/2///62656_1#AAA001##1`         | Cross-dictionary references     |
| Short     | `AAA001`                             | Same-dictionary references      |
| Commented | `0112/2///62656_1#AAA001##1###note`  | Optional annotation             |

## Grammar

```
ICID    ::= supplier "#" code "##" version ["###" comment]
supplier ::= RA-IRDI per ISO/IEC 11179-6 ; e.g. "0112/2///62656_1"
code    ::= identifier ; short form like "AAA001" or "MDC_C002"
version ::= positive integer
comment ::= free-form short text
```

- `0112/2///62656_1` is the **RA-IRDI** (Registration Authority) for
  IEC CDD.
- `AAA001` is the **item identifier** within that supplier's scope.
- `##1` is the **version**.
- `###note` is optional **comment** metadata — not part of identity.

## Resolution

`Opencdd::Database` accepts all three forms interchangeably:

```ruby
db.find(Opencdd::IRDI.parse("0112/2///62656_1#AAA001##1"))
db.find_by_code("AAA001")                        # short form
db.resolve_reference("AAA001")                   # polymorphic
```

`Database#resolve_reference` tries, in order:

1. Full IRDI parse → direct lookup
2. Symbolic name → symbol table
3. Short code → `find_by_code`
4. Fallback parse as IRDI

## Equality

Two IRDIs are equal iff they resolve to the same entity
(supplier + code + version). Comment is metadata, not identity.

```ruby
a = Opencdd::IRDI.parse("0112/2///62656_1#AAA001##1")
b = Opencdd::IRDI.parse("0112/2///62656_1#AAA001##1###note")
a == b    # => true (comment ignored)
a.hash == b.hash   # => true
```

## Meta-class IRDIs

The fixed set of meta-class IRDIs (M2 layer) per IEC 61360:

| Meta-class   | IRDI        | Ruby class              |
|--------------|-------------|-------------------------|
| Dictionary   | `MDC_C001`  | *(not modeled)*         |
| Class        | `MDC_C002`  | `Opencdd::Klass`        |
| Property     | `MDC_C003`  | `Opencdd::Property`     |
| Supplier     | `MDC_C004`  | *(not modeled)*         |
| ValueList    | `MDC_C005`  | `Opencdd::ValueList`    |
| Datatype     | `MDC_C006`  | *(not modeled)*         |
| Document     | `MDC_C007`  | *(not modeled)*         |
| Object       | `MDC_C008`  | *(not modeled)*         |
| Unit         | `MDC_C009`  | `Opencdd::Unit`         |
| ValueTerm    | `MDC_C010`  | `Opencdd::ValueTerm`    |
| Relation     | `MDC_C011`  | `Opencdd::Relation`     |
| ViewControl  | `EXT_C001`  | `Opencdd::ViewControl`  |

The single source of truth for this mapping is
`Opencdd::MetaClasses` (`lib/opencdd/meta_class.rb`).

## Property IDs

Every property on every meta-class has its own IRDI. The canonical
source for these is `Opencdd::PropertyIds::REGISTRY`
(`lib/opencdd/property_ids.rb`). No raw `"MDC_P###"` literal should
appear outside that file — `bin/lint-no-raw-mdc` enforces this.

## See also

- [Property registry](https://github.com/opencdd/opencdd-ruby/blob/main/lib/opencdd/property_ids.rb)
- [ISO/IEC 11179-6](https://www.iso.org/standard/80115.html) — normative
