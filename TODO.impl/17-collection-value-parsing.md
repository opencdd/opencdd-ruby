# Plan 17 — Collapse collection-value parsing into one seam

## Why

Six call sites reimplement "strip delimiters, split on commas, reject
empties" independently:

- `lib/opencdd/database.rb` `normalize_reference_collections!`
- `lib/opencdd/cddal/builder.rb` `resolve_property_value`
- `lib/opencdd/cddal/serializer.rb` `format_set`
- `lib/opencdd/validator/reference_rule.rb` `refs`
- `lib/opencdd/validator/class_reference_rule.rb` `refs`
- `lib/opencdd/structured_values.rb`

`Opencdd::ParseHelpers` already provides some of the pieces
(`unwrap_delimiters`, `brace_wrapped?`, `paren_wrapped?`) but only
three callers use them.

When the delimiter convention evolves (whitespace handling, nested
braces, quoted commas) six files must be found and patched in lock
step. A bug found in one site is a bug latent in five others.

## Scope

Single deep module: `Opencdd::StructuredValues.unwrap_and_split(value)`
that owns the brace/paren/comma convention. All six call sites
collapse to one call.

## Approach

1. Add `StructuredValues.unwrap_and_split(value)` — strips `{}`/`()`
   wrappers, splits on commas (respecting nested `{}`/`()`),
   strips whitespace, rejects empties. Returns `Array<String>`.
2. Add `StructuredValues.rejoin(elements)` — inverse: joins with
   `,` and wraps in `{}`. (Replaces the six `"{#{x.join(',')}}"` patterns.)
3. Migrate each call site. Preserve call-site semantics; only the
   implementation changes.
4. Spec the new seam with edge cases: empty string, `{}`, `()`,
   nested `{(a,b),(c,d)}`, whitespace, trailing comma, quoted
   commas (not currently supported — note as known limitation).

## Acceptance

- [x] `StructuredValues.unwrap_and_split` exists and is the SSOT.
- [x] All six migrated call sites use it.
- [x] `grep -rn "split.*,.*reject.*empty" lib/opencdd/` returns only
      the new SSOT.
- [x] New spec file covers edge cases.
- [x] 700+ existing specs still pass.

## Dependencies

None. Foundational.
