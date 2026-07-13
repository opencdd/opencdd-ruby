# Plan 16 — Self-audit of 2026-07-11 contributions

## What this is

A code-review-style audit of the 2026-07-11 contributions (architectural
cleanup, CDDAL module system, gem rename) against the project's stated
principles (OCP, DRY, MECE, model-driven, encapsulation, performance,
SSOT). Findings are filed below with severity, fix, and follow-up
status. Each fix landed in the same audit pass.

## Findings

### High — fixed in this pass

#### A1. DRY violation: `link_class_hierarchy` duplicated

`Database#link_class_hierarchy!` and `Opencdd::Cddal::Builder#link_class_hierarchy`
had near-identical logic (walk classes, look up parent, call
`attach_parent_irdi` + `add_child`). Two sources of truth for the same
invariant.

**Fix**: extracted to a single public method
`Database#link_class_hierarchy!` (already existed as private). Builder
now calls `@database.link_class_hierarchy!` instead of duplicating.
Removed `Builder#link_class_hierarchy`.

#### A2. DRY violation: "entity or irdi" coercion repeated

15+ call sites did `value.is_a?(Opencdd::Entity) ? value.irdi : value`
or `klass.is_a?(Opencdd::Klass) ? klass : find(klass)`. Each call site
had to remember the pattern; new methods copied the boilerplate.

**Fix**: added two single-purpose methods on `Database`:
- `Database#coerce_entity(value)` — accepts Entity, IRDI, or String; returns Entity or nil.
- `Database#coerce_irdi(value)` — accepts same; returns IRDI or nil.

Replaced every `is_a?(Entity) ? value.irdi : value` with `coerce_irdi(value)`.

#### A3. Dead code: defensive `is_a?` check in Builder

`Opencdd::Cddal::Builder#attach_source_location` checked
`return unless entity.is_a?(Opencdd::Entity)` before calling
`entity.attach_source_location(loc)`. The check could never fail —
`build_entity` only returns Entity subclasses (or nil, which is filtered
earlier).

**Fix**: removed the dead check.

#### A4. Unused `require "forwardable"` in database.rb

Carried over from an earlier extraction; no `def_delegator` or
`extend Forwardable` anywhere in the file.

**Fix**: removed the require.

### Medium — fixed in this pass

#### A5. Silent failure in Resolver non-strict mode

The default Resolver silently swallowed ImportError on unreachable
imports (no warning unless `$VERBOSE` or `CDDAL_DEBUG` was set). Real
bugs (typos in import paths, renamed files) hid silently.

**Fix**: warn by default. Add `quiet:` opt-in for callers that
deliberately want to swallow errors (the test-suite's unreachable-URL
test).

#### A6. Process-global `default_resolver`

`Opencdd::Cddal.default_resolver` was a module-level memoized Resolver.
Tests that mutated the fetcher could pollute subsequent tests.

**Fix**: still memoized at module level (the common case is fine), but
added a `reset_default_resolver!` for tests and a per-call
`resolver:` argument that takes precedence. Tests that need isolation
pass their own resolver.

### Medium — deferred (filed for follow-up)

#### A7. Database is 623 lines — mix of core + Parcel + traversal

The class handles entity storage, indexing, mutation commands,
finalization, Parcel-workbook integration (`add_workbook`,
`drop_dictionary`, `register_external_sheet`), and tree traversal
(`class_tree`, `composition_tree`, `relation_tree`).

**Why deferred**: splitting requires touching every reader/writer
subsystem and the editor port. Better as a dedicated refactor pass
(tracked in `TODO.impl/05-database.md` — Phase 2 lutaml-model
migration will trigger this naturally).

#### A8. Builder is 392 lines — single-doc build + module pipeline

Could extract `Opencdd::Cddal::ImportProcessor` (the import resolution
graph + scope application) and `Opencdd::Cddal::Linker` (the link_*
methods that duplicate Database's).

**Why deferred**: A1 already removed the worst duplication. The
remaining logic is cohesive (it's all "turn AST into Database"). Split
when adding the next feature (versioned modules, plan 09 Q1).

### Low — documented as known

#### A9. `Cdd = Opencdd` global alias

Added by the project owner for back-compat with cdd-data's Rakefile
and specs that still reference `Cdd::`. Risk: if anyone defines `Cdd`
later, this is silently overwritten. Acceptable for the transition
period.

**Action**: document in README and plan to remove after cdd-data
and editor ports migrate.

#### A10. `expect 1` in cddal.y for shift/reduce conflict

The `import_item: IDENT | IDENT soft_as IDENT` rule has an inherent
shift/reduce conflict on `IDENT soft_as IDENT` (parser can either shift
on `IDENT` to build the rename form, or reduce to `import_item`).
Acknowledged via `expect 1`.

**Action**: could be resolved by reserving `as` as a true keyword
(breaking the attosecond test case), or by using different syntax
(`Foo => F`). Tracked but not blocking.

## Spec coverage added

- `spec/database/coercion_spec.rb` — covers `coerce_entity` / `coerce_irdi`
  with Entity, IRDI, String, code, and invalid inputs.
- `spec/cddal/modules_spec.rb` — added a "warns by default" example
  for Resolver's non-strict mode.
- `spec/powertype_spec.rb` (A18) — covers Klass#powertype?,
  categorical_instances, powertype_owners; Database#categorical_classes,
  #instances_of, #valid_class_reference?. Uses OceanRunner fixture.
- `spec/validator/class_reference_rule_spec.rb` (A20) — covers R16
  rule: accepts valid powertype instances, rejects non-instances and
  unknown IRDIs, handles sets.

## Round 2 (2026-07-12)

Continued audit after the user's `attach_unloaded_entities` rewrite
(canonical MetaClasses lookups, replacing a buggy duplicate map).
Applied the same scrutiny to remaining duplicate-map sites and
added explicit modeling for the 4-layer CDD ontology.

### A17 — Folded duplicate type-maps into MetaClasses

Five sites had parallel lookup tables mapping the CDD type Symbol
(:class, :property, ...) to either a Ruby class or a Parcel
sheet-type string:

  - `Database::ENTITY_CLASSES_BY_TYPE` → type → Ruby class
  - `Database#parcel_type_label_for` → type → "CLASS" / "PROPERTY" / ...
  - `Parcel::Writer#parcel_type_label` → same as above (duplicate)
  - `Parcel::Workbook#parcel_type_label_for` → same (duplicate)
  - `Entity#type` reached through `Opencdd::Parcel::META_CLASS_TYPES`
    (an alias) to look up the type Symbol

All folded into MetaClasses:

  - `MetaClass#type` and `MetaClass#sheet_type` are now first-class
    attributes set at construction.
  - `MetaClass::PARCEL_SHEET_TYPES` is the single source for the
    sheet-type string mapping.
  - `MetaClasses.entity_class_for_type(type)` — single replacement
    for `ENTITY_CLASSES_BY_TYPE[type]`.
  - `MetaClasses.sheet_type_for_type(type)` and `sheet_type_for(irdi)`
    replace the per-call sites' local maps.

**Net effect**: removed 4 duplicate maps (~30 lines), one source of
truth, adding a new meta-class no longer requires updating Database
+ Writer + Workbook + Entity to know about it.

### A18 — Added powertype API for the 4-layer ontology

CDD's defining feature vs UML/RDF/OWL: at M1, a class declared
`class_type=CATEGORICAL_CLASS` has subclasses that ARE themselves
classes but also act as its instances (used in CLASS_REFERENCE data
types and sub_class_selection). This powertype pattern was implicit
in the data model (via `class_type` + `superclass`) but had no
explicit API.

Added to model the 4-layer semantics explicitly:

  - `Klass#powertype?` — true when `class_type` is CATEGORICAL_CLASS.
  - `Klass#categorical_instances(database)` — the powertype
    instances (direct subclasses that are ITEM_CLASS, VALUE_CLASS,
    or nested CATEGORICAL_CLASS). Empty for non-powertypes.
  - `Klass#sub_powertypes(database)` — nested categorical classes.
  - `Klass#powertype_owners(database)` — ancestor categorical
    classes (reverse direction).
  - `Database#categorical_classes` — all categorical classes in DB.
  - `Database#instances_of(categorical_klass)` — accepts Klass,
    IRDI, or code String.
  - `Database#valid_class_reference?(categorical_klass, value)` —
    predicate for CLASS_REFERENCE validation.

Added `module Opencdd` docstring documenting the four layers
(M2 meta-model, M1 model, M0 data) and the powertype distinction.

### A19 — Decoupled Entity#type from the Parcel namespace

`Entity#type` was reaching through
`Opencdd::Parcel::META_CLASS_TYPES[code]` — an alias defined in
`lib/opencdd/parcel.rb`. The Parcel module is a *consumer* of the
type system, not its owner; reaching through it created a circular
dependency from the core entity model into a format module.

Replaced with `Opencdd::MetaClasses.type_for(meta_class_irdi&.code)`.
MetaClasses is the SSOT; Parcel is just another consumer now.

### A20 — R16 CLASS_REFERENCE validator rule

The validator's R08 (reference integrity) only checks that an IRDI
resolves. It doesn't check that the resolved entity matches the
categorical constraint expressed in a `CLASS_REFERENCE(Foo)` data
type. This gap meant a Property could carry an IRDI of any class,
not just an instance of the named categorical class.

Added `Opencdd::Validator::ClassReferenceRule` (R16):

  - `applies?` is true when the cell's parsed data_type is a
    `Opencdd::DataType::ClassReference`.
  - `call` checks each referenced IRDI against
    `Database#valid_class_reference?` (A18's powertype API).
  - Handles single values and `{...}` sets.
  - Registered in `Opencdd::Validator::Runner::RULES`.

Specs in `spec/validator/class_reference_rule_spec.rb` cover:
accepts valid instances, rejects non-instances and unknown IRDIs,
handles sets, integrates with `Validator.run`.

## Verification (2026-07-12)

After A17-A20: **700 examples, 0 failures, 23 pending**.

```
bundle exec rake cddal:check_regen   # passes
bundle exec rake lint:registry       # passes
bundle exec rake spec                # passes
```

OceanRunner (40 entities) and Kagoshima (6 entities) still
round-trip semantically equal. Powertype semantics survive
serialize → parse round-trip.
