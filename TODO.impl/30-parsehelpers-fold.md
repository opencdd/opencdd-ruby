# Plan 30 — ParseHelpers folds into StructuredValues + FieldReader

## Why

Post-P17, `StructuredValues.unwrap_and_split` is the SSOT for
brace/paren splitting. But `ParseHelpers` still carries:

- `unwrap_delimiters`, `paren_wrapped?`, `brace_wrapped?`
- `parse_pair_list`, `parse_synonym_tuples`
- `SynonymTupleScanner` (uses `StringScanner`)

And `FieldReader` has its own inline delimiter stripping.

Three code paths for the same wire format (Parcel `{a,b,c}`,
CDDAL `{a,b,c}`, JSON-internal arrays).

## Scope

Migrate the three ParseHelpers users (`Klass#properties_on_class`,
`Property#active_for?`, others via `include ParseHelpers`) to
`StructuredValues` directly. Remove the duplicate parsing from
`FieldReader`.

Keep `ParseHelpers` as a private mixin for legacy callers but mark
it for removal.

## Approach

1. Replace `parse_irdi_list(raw)` callers with
   `StructuredValues.parse_ref_set(raw)`.
2. Replace `parse_string_list(raw)` callers with
   `StructuredValues.unwrap_and_split(raw)`.
3. Move `SynonymTupleScanner` into `StructuredValues.parse_synonyms`.
4. Mark `ParseHelpers` deprecated.

## Acceptance

- [x] `StructuredValues` is the SSOT.
- [x] No new callers of `ParseHelpers`.
- [x] All specs pass.

## Dependencies

None. Foundational — do first.
