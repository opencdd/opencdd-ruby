# Plan 03 — Domain model (entities + value objects)

## Why

The domain model is the canonical in-memory representation of CDD content.
Every format reader, writer, validator, and exporter targets this model.
Getting it right is a precondition for Parcel parity (plan 06), CDDAL
round-trip (plans 07–08), and validation (plan 10).

The model already exists in `lib/cdd/`. This plan audits each class against
IEC 61360 / IEC 62656-1 / `cdd-data/specs/parcelmaker/`, documents the
typed accessors each class must expose, and confirms the powertype-faithful
invariants.

## Scope

Define and lock down the **public API** of every model class. Internal
representation is private and may change (especially in plan 15's
lutaml-model migration). Downstream code targets only the public API.

Not in scope: the registry itself (plan 04), the Database (plan 05),
the Parcel/CDDAL formats (plans 06–09).

## Approach

### Entity (lib/cdd/entity.rb) — base class

Every CDD object is an `Entity`. Fields:

| Method                       | Type                | Source ID |
|------------------------------|---------------------|-----------|
| `irdi`                       | `Cdd::IRDI`         | —         |
| `meta_class_irdi`            | `Cdd::IRDI`         | —         |
| `type`                       | `Symbol`            | derived from meta_class |
| `code`                       | `String`            | meta-class-specific code property (e.g. `MDC_P001_5` for class) |
| `properties`                 | `Hash{String=>String}` | raw property ID → value (lossless) |
| `schema`                     | `Symbol`            | sheet family this entity came from (for diagnostics) |
| `preferred_name`             | `String`            | `MDC_P004` (current language) |
| `preferred_name(lang:)`      | `String`            | per-language |
| `synonymous_names`           | `Array<[String,String]>` | `MDC_P007` structured |
| `short_name`                 | `String`            | `MDC_P005` |
| `definition`                 | `String`            | `MDC_P006` |
| `source_document_of_definition` | `String`         | `MDC_P006_1` |
| `note`                       | `String`            | `MDC_P008` |
| `remark`                     | `String`            | `MDC_P009` |
| `version_number`             | `Integer`           | `MDC_P002_1` |
| `revision_number`            | `Integer`           | `MDC_P002_2` |
| `time_stamp` / dates         | `Date`/`Time`       | `MDC_P003_*` |
| `guid`                       | `String`            | `MDC_P066` |
| `source_document`            | `String`            | `MDC_P006_1` |

Invariants:
- `Entity` instances are frozen after construction.
- `properties` is the lossless raw store; typed accessors read from it
  via `Cdd::PropertyIds::<CONST>` lookups.
- `Entity#type` is derived from `meta_class_irdi` via `Cdd::MetaClasses`.
- `Entity#database` is a transient back-pointer set by `Database#add_entity`,
  not part of the value identity.

### Klass (lib/cdd/klass.rb) — class entity

Extends `Entity` for entities whose `meta_class_irdi == MDC_C002`.

| Method                         | Type                    | Source |
|--------------------------------|-------------------------|--------|
| `parent_irdi`                  | `Cdd::IRDI`             | `MDC_P010` |
| `parent`                       | `Cdd::Klass` or nil     | resolves parent_irdi via Database |
| `children`                     | `Array<Cdd::Klass>`     | reverse index |
| `class_type`                   | `Cdd::ClassType`        | `MDC_P011` |
| `is_case_of_irdis`             | `Array<Cdd::IRDI>`      | `MDC_P013` |
| `applicable_property_irdis`    | `Array<Cdd::IRDI>`      | `MDC_P014` |
| `imported_property_irdis`      | `Array<Cdd::IRDI>`      | `MDC_P090` (fix from plan 02) |
| `sub_class_selection_irdis`    | `Array<Cdd::IRDI>`      | `MDC_P016` (fix from plan 02) |
| `supplier_irdi`                | `Cdd::IRDI`             | `MDC_P012` |
| `applicable_types`             | `Array<Cdd::IRDI>`      | `MDC_P015` |
| `applicable_documents`         | `Array<Cdd::IRDI>`      | `MDC_P094` |

Power-type invariant: a Klass with `class_type == CATEGORICAL_CLASS` may
have instances that are themselves classes (instance-of-class-of-class).
The model must not forbid this; the Database (plan 05) maintains the
reverse index `instancesOf[class_irdi] = [klass, ...]`.

### Property (lib/cdd/property.rb) — property entity

Extends `Entity` for entities whose `meta_class_irdi == MDC_C003`.

| Method                            | Type                       | Source |
|-----------------------------------|----------------------------|--------|
| `property_data_element_type`      | `Cdd::PropertyDataTypeElement` | `MDC_P020` |
| `definition_class_irdi`           | `Cdd::IRDI`                | `MDC_P021` (fix) |
| `data_type`                       | `String` (raw)             | `MDC_P022` (fix) |
| `parsed_data_type`                | `Cdd::DataType`            | parses `data_type` |
| `unit_irdi`                       | `Cdd::IRDI`                | `MDC_P041` (fix) |
| `alternative_unit_irdis`          | `Array<Cdd::IRDI>`         | `MDC_P042` (fix) |
| `quantity_irdi`                   | `Cdd::IRDI`                | `MDC_P114` |
| `value_format`                    | `Cdd::ValueFormat`         | `MDC_P024` (fix) |
| `formula` / `formula_localized`   | `String`                   | `MDC_P027_1`/`MDC_P027_2` (fix) |
| `symbol_in_text` / `symbol_in_sgml` | `String`                 | `MDC_P025_1`/`MDC_P025_2` (fix) |
| `condition`                       | `Cdd::Condition`           | `MDC_P028` |
| `constraint`                      | `String`                   | `MDC_P068` (fix) |
| `value_list_irdi`                 | `Cdd::IRDI`                | derived from `parsed_data_type` when ENUM |
| `super_property_irdi`             | `Cdd::IRDI`                | `MDC_P110` |
| `requirement`                     | `Symbol` (:key/:mand/:opt) | `MDC_P097` |

### Unit (lib/cdd/unit.rb) — unit entity

`meta_class_irdi == MDC_C009`.

| Method                | Type    | Source |
|-----------------------|---------|--------|
| `unit_code`           | String  | `MDC_P001_10` |
| `names`               | multilingual | `MDC_P004` |
| `unit_symbol`         | String  | `MDC_P025_1` (repurposed) |
| `unit_in_text`        | String  | `MDC_P023_1` |

### ValueList (lib/cdd/value_list.rb) — enumeration entity

`meta_class_irdi == MDC_C005`.

| Method                | Type                     | Source |
|-----------------------|--------------------------|--------|
| `value_list_code`     | String                   | `MDC_P001_12` |
| `terms`               | `Array<Cdd::ValueTerm>`  | reverse index from ValueTerm's `MDC_P025_1` |
| `enumerated_code_list`| String                   | `MDC_P044` |
| `controlling_property_irdis` | `Array<Cdd::IRDI>` | reverse: properties referencing this list |

### ValueTerm (lib/cdd/value_term.rb) — term entity

`meta_class_irdi == MDC_C010`.

| Method                | Type                | Source |
|-----------------------|---------------------|--------|
| `term_code`           | String              | `MDC_P001_11` |
| `preferred_letter_symbol` | String          | `MDC_P025_1` |
| `value_list_irdi`     | `Cdd::IRDI`         | resolves via Database |

### Relation (lib/cdd/relation.rb) — relation entity

`meta_class_irdi == MDC_C011` (fix from plan 02).

| Method                    | Type                  | Source |
|---------------------------|-----------------------|--------|
| `relation_type`           | `Cdd::RelationType`   | `MDC_P200` |
| `domain_irdis`            | `Array<Cdd::IRDI>`    | `MDC_P201` |
| `codomain_irdis`          | `Array<Cdd::IRDI>`    | `MDC_P202`/`MDC_P203` |
| `domain_element_type`     | `Cdd::DataType`       | `MDC_P208` |
| `codomain_element_type`   | `Cdd::DataType`       | `MDC_P209` |
| `super_relation_irdi`     | `Cdd::IRDI`           | `MDC_P212` |

### ViewControl (lib/cdd/view_control.rb)

`meta_class_irdi == EXT_C001`.

| Method                    | Type                | Source |
|---------------------------|---------------------|--------|
| `view_control_code`       | String              | `EXT_P001` |
| `controlled_class_irdis`  | `Array<Cdd::IRDI>`  | `EXT_P002` |
| `shown_property_irdis`    | `Array<Cdd::IRDI>`  | `EXT_P003` |

### Value objects (frozen, immutable)

| Class | File | Purpose |
|-------|------|---------|
| `Cdd::IRDI` | `irdi.rb` | Parses 3 forms (full/short/commented); comparable; hashable. |
| `Cdd::ClassType` | `class_type.rb` | ITEM_CLASS, CATEGORICAL_CLASS, etc. |
| `Cdd::DataType` | `data_type.rb` | Primitive tokens + ENUM_*(list) + CLASS_REFERENCE(class) + AGGREGATE nesting (depth ≤ 3). |
| `Cdd::ValueFormat` | `value_format.rb` | IEC 61360-2 NR1/NR2/NR3/M/B/Date/DT/Bool tokens. |
| `Cdd::Condition` | `condition.rb` | Equality predicates (`==`, `!=`) on property refs; sets for OR. |
| `Cdd::PropertyDataTypeElement` | `property_data_element_type.rb` | NON_DEPENDENT_P_DET, DEPENDENT_P_DET, CONDITION_DET, etc. |
| `Cdd::RelationType` | `relation_type.rb` | FUNCTION, etc. |
| `Cdd::Languages` | `languages.rb` | Source/translation language list per workbook. |

### Construction pattern

All model classes use keyword-init constructors:

```ruby
Cdd::Klass.new(
  irdi: "0112/2///62656_1#AAA001##1",
  properties: { "MDC_P001_5" => "AAA001", "MDC_P010" => "UNIVERSE", ... },
  schema: :class,
  meta_class_irdi: "MDC_C002",
)
```

`Database#add_entity` then attaches the back-pointer and updates reverse
indexes. Entities are frozen at end of construction.

## Acceptance criteria

- [x] Every public method listed above exists and returns the documented type.
- [x] `bundle exec rspec spec/entity_spec.rb spec/klass_spec.rb
      spec/property_spec.rb spec/unit_spec.rb spec/value_list_spec.rb
      spec/value_term_spec.rb spec/relation_spec.rb spec/view_control_spec.rb`
      green.
- [x] A round-trip Property → properties hash → Property preserves the
      typed accessor outputs.
- [x] Powertype invariant: a `Klass` whose `class_type` is
      `CATEGORICAL_CLASS` may appear in another `Klass`'s
      `is_case_of_irdis` without raising.
- [x] No `to_h`, `to_json`, `from_h`, `serialize`, or `deserialize`
      instance method on any model class.

## Dependencies

- **Plan 01** — conventions.
- **Plan 02** — property ID fixes must land before reads can be correct.
- Blocks **plan 05** (Database indexes entities), **plan 06** (Parcel
  readers construct entities), **plan 07** (CDDAL Builder constructs
  entities), **plan 10** (validator walks entities).

## Open questions

- **Q1.** Should `Entity#properties` be a `Hash` or a typed collection?
  Current: plain `Hash`. **Recommendation:** keep plain `Hash` until
  lutaml-model migration (plan 15) — typed collection adds friction
  for the lossless raw store.
- **Q2.** How do we represent unknown property IDs encountered in a
  Parcel xlsx (not in the REGISTRY)? **Recommendation:** preserve them
  verbatim in `properties`; expose via `Entity#raw_property(id)` only.
  Don't add typed accessors for non-registry IDs.
- **Q3.** Should there be a `Dictionary` and `Supplier` entity class
  (for `MDC_C001` / `MDC_C004`)? **Recommendation:** yes, but defer to
  a follow-up — current readers don't need to model them as entities;
  they live in the `Project` and `pcls_LOCAL` sheets.
