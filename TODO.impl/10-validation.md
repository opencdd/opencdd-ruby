# Plan 10 — Validator (rules R01–R15)

## Why

ParcelMaker's defining interactive feature is real-time cell validation
(F06): every keystroke runs the rules and the cell turns red on
violation. The Ruby gem must expose the same predicates so the OpenCDD
Editor can reuse them, and so CI builds can fail on invalid CDD content.

`cdd-data/specs/parcelmaker/04_validation_rules.md` enumerates the rules
R01–R15. The Ruby gem already has `lib/cdd/validator.rb` plus a
per-rule class in `lib/cdd/validator/*.rb`. This plan locks the public
predicate API and confirms each rule's semantics match the spec.

## Scope

- `Cdd::Validator` — composite runner + module-level predicate methods.
- `Cdd::Validator::Rule` — abstract base.
- Per-rule classes (`R01IrdiSyntax` … `R15CompositionAcyclic`).
- `Cdd::ValidationError` struct.
- Reusable predicates exported for the editor.

Not in scope: the UI rendering of errors (editor concern).

## Approach

### Public predicate API

These are reused by the OpenCDD Editor's live validator. Module-level
methods on `Cdd::Validator`:

```ruby
Cdd::Validator.irdi_well_formed?(value)                    # R01
Cdd::Validator.code_unique?(database, code, type:)         # R02
Cdd::Validator.type_valid?(value, data_type)               # R03
Cdd::Validator.enum_member?(value, value_list)             # R04
Cdd::Validator.format_valid?(value, value_format)          # R05
Cdd::Validator.pattern_valid?(value, pattern)              # R06
Cdd::Validator.mandatory_present?(value)                   # R07
Cdd::Validator.reference_exists?(value, database)          # R08
Cdd::Validator.set_well_formed?(value)                     # R09
Cdd::Validator.synonym_set_well_formed?(value)             # R10
Cdd::Validator.condition_well_formed?(value)               # R11
Cdd::Validator.data_type_well_formed?(value)               # R12
Cdd::Validator.format_compatible?(data_type, value_format) # R13
Cdd::Validator.class_hierarchy_acyclic?(database)          # R14
Cdd::Validator.composition_acyclic?(database)              # R15

Cdd::Validator.cell_valid?(entity, property_id, database)  # composite
Cdd::Validator.run(database)                               # → Array<ValidationError>
```

### ValidationError

```ruby
Cdd::ValidationError = Struct.new(
  :entity_irdi, :property_id, :rule, :message, :source_location, keyword_init: true,
)
```

`source_location` is the `Struct(:file, :line)` from plan 09. Used to
render clickable error locations in any UI.

### Rule classes (lib/cdd/validator/*.rb)

| File | Rule | What it checks |
|------|------|----------------|
| `irdi_rule.rb` | R01 | IRDI / ICID syntax per `Cdd::IRDI.well_formed?`. |
| `uniqueness_rule.rb` | R02 | Code uniqueness within a sheet (`#REQUIREMENT = KEY`). |
| `data_type_rule.rb` | R03 | Value parses per its declared data type. |
| `enum_rule.rb` | R04 | Value is a member of the column's value list. |
| `format_rule.rb` | R05 | Value matches the IEC 61360 value-format token. |
| `pattern_rule.rb` | R06 | Value matches the column's PCRE pattern. |
| `mandatory_rule.rb` | R07 | Non-empty for `MAND` / `KEY` columns. |
| `reference_rule.rb` | R08 | Every referenced IRDI exists (in DB or imports). |
| `set_rule.rb` | R09 | `{a,b,...}` and `{(a,b),...}` well-formed. |
| `synonym_rule.rb` | R10 | Synonymous-name set well-formed. |
| `condition_rule.rb` | R11 | Condition well-formed (predicate or set of `(IRDI, value)`). |
| `type_rule.rb` | R12 | Data-type expression well-formed. |
| `format_compatible_rule.rb` (R13) | R13 | Value-format compatible with data type. |
| `hierarchy_rule.rb` | R14 | Class hierarchy acyclic (superclass chain). |
| `composition_rule.rb` (R15) | R15 | Composition hierarchy acyclic. |

Each rule class implements:

```ruby
class Cdd::Validator::Rule::R01IrdiSyntax < Cdd::Validator::Rule
  def self.id; :R01; end
  def self.applies_to?(entity, property_id, database); ...; end
  def self.check(entity, property_id, value, database); ...; end  # → ValidationError?
end
```

The `Runner` (lib/cdd/validator/runner.rb) iterates rules × entities ×
properties and aggregates errors.

### Composite runner

```ruby
errors = Cdd::Validator.run(database)
errors.first.entity_irdi
errors.first.source_location.file
errors.first.source_location.line
```

Honors a `strict:` flag (default `true`). When false, missing references
in imported modules produce warnings instead of errors (per plan 09).

### Live-validation hook

```ruby
Cdd::Validator.cell_valid?(entity, property_id, database)
```

Returns `true` if all applicable rules pass for that single cell. Used
by the editor's keystroke-time validator. Walks only the rules declared
for the property's data type / value kind.

### Spec coverage

`spec/validator_spec.rb` plus per-rule spec files. Each rule has at
least three cases: a clear pass, a clear fail, and a tricky edge case
from the cdd-data spec.

## Acceptance criteria

- [ ] Every predicate listed above is public on `Cdd::Validator` and
      has at least one spec.
- [ ] `Validator.run` returns zero errors on the ParcelMaker nuts
      fixture and on the OceanRunner fixture.
- [ ] On a deliberately-broken fixture (hand-crafted), `Validator.run`
      returns the expected rule violations.
- [ ] `cell_valid?` short-circuits on the first applicable rule's
      failure; performance is O(1) per cell for typical schemas.
- [ ] Source location flows through to the ValidationError so the
      editor can navigate to the offending line.
- [ ] All `spec/validator*_spec.rb` files green.

## Dependencies

- **Plan 03** — entities.
- **Plan 04** — IRDI / data types / value formats.
- **Plan 05** — Database (hierarchy / composition walkers).
- **Plan 09** — `source_location` for error reporting.

## Open questions

- **Q1.** Should `Validator.run` short-circuit on the first error per
  entity, or collect all errors? **Recommendation:** collect all — the
  UI renders them as a list and the user fixes them in one pass.
- **Q2.** Performance budget for `cell_valid?`? Used per keystroke in
  the editor. **Recommendation:** target <1ms per call on a 100k-entity
  Database. Memoize parsed data types / value formats.
