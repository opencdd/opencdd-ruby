# Plan 27 — Deepen the Validator::Rule base — 12 rules share boilerplate

## Why

`Opencdd::Validator::Rule` is 23 lines of three abstract methods. The
12 rule subclasses each reimplement shared guards:

- Blank-value guard: `return true if value.nil? || value.to_s.strip.empty?`
  duplicated in all 12 rules' `call` methods.
- `code_column?` predicate duplicated in `IrdiRule` and `UniquenessRule`.
- `%i[identifier_ref set_of_refs class_ref]` reference-kind set
  appears in `ReferenceRule`, `IrdiRule`, `Builder` independently.

The Rule base class is purely nominal — deleting it removes zero
behavior.

## Scope

Deepen `Rule` to own:
- The blank-value guard (overridable via `skip_blank?`).
- The reference-kind predicate.
- The code-column predicate.
- A canonical "applies + call + message" template that subclasses
  override via small focused methods (`value_passes?(value, context)`).

## Approach

```ruby
class Opencdd::Validator::Rule
  REFERENCE_VALUE_KINDS = %i[identifier_ref set_of_refs class_ref].freeze

  def applies?(context)
    true
  end

  def call(value, context)
    return true if blank?(value) && skip_blank?
    value_passes?(value, context)
  end

  def message(value, context)
    "#{id}: validation failed for #{value.inspect}"
  end

  # ── Hooks for subclasses ────────────────────────────────────
  def value_passes?(value, context)
    raise NotImplementedError
  end

  # Most rules skip empty values — the MandatoryRule overrides.
  def skip_blank? = true

  # ── Shared predicates ───────────────────────────────────────
  def blank?(value)
    value.nil? || value.to_s.strip.empty?
  end

  def code_column?(context)
    context.column_iri == Opencdd::MetaClasses.code_property_id_for(context.entity.meta_class_irdi&.code)
  end

  def reference_kind?(context)
    REFERENCE_VALUE_KINDS.include?(context.value_kind)
  end
end
```

Migrate each rule subclass to override `value_passes?` only.

## Acceptance

- [x] Rule base owns shared guards.
- [x] Each subclass overrides `value_passes?` (smaller surface).
- [x] `code_column?` and `reference_kind?` defined once.
- [x] No spec regression.

## Dependencies

None.
