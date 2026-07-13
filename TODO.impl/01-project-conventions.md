# Plan 01 — Project conventions and non-negotiable rules

## Why

The `opencdd` gem is a fresh extraction that will be touched by many plans.
Before any feature work, every contributor (human or AI) needs a single
reference for the conventions that govern the codebase. These rules override
default instincts and apply uniformly across all plans in this set.

## Scope

Codify the project's conventions so they are enforceable and self-contained.
This plan is **reference material** — it produces no code; it produces a
checklist every other plan conforms to.

## Conventions

### Naming

- The gem is published as **`opencdd`** on RubyGems.
- The Ruby module is **`Cdd`**. The module name appears in every class
  path (`Cdd::Entity`, `Cdd::Klass`, `Cdd::Parcel::Workbook`, …).
- Both `require "opencdd"` and `require "cdd"` work (`lib/opencdd.rb`
  forwards to `lib/cdd.rb`).
- Never name a class `Class` — the IEC entity type is `Cdd::Klass`.

### Library load structure

- **`autoload` only** inside `lib/`. Never `require_relative` for library
  code. Never `require "<absolute path>"` for library code.
- Define autoload entries in the **immediate parent namespace's file**.
  Examples:
  - `lib/cdd.rb` declares `autoload :Database, "cdd/database"`.
  - `lib/cdd/parcel.rb` declares `autoload :WorkbookReader, "cdd/parcel/workbook_reader"`.
  - `lib/cdd/cddal.rb` declares `autoload :Lexer, "cdd/cddal/lexer"`.
- If a new namespace file doesn't exist, create it. Do not scatter autoloads.
- The gemspec is the **only** place `$LOAD_PATH.unshift` is acceptable.

### Specs (from global CLAUDE.md)

- **Never `double()`**. Use real model instances. If a model is hard to
  construct, build a `Struct.new(*attrs)` factory in `spec/support/`.
- Test behavior (output and state), not interactions.
  "Should have received" mocks are testing implementation, not correctness.
- `expect_with :rspect` syntax only (no `should`).
- `config.disable_monkey_patching!` — already set in `spec/spec_helper.rb`.
- Specs that touch fixtures use the constants in `spec/spec_helper.rb`
  (`PARCEL_MAKER_XLSX`, `NUTS_XLSX`, `KAGOSHIMA_CDDAL`, `LEGACY_XLS_DIR`,
  `LEGACY_SINGLE_XLS`).

### Serialization

- **Never write `def to_h`, `def to_json`, `def from_h`, `def serialize`,
  `def deserialize` on a model class** (`Entity`, `Klass`, `Property`,
  `Unit`, `ValueList`, `ValueTerm`, `Relation`, `ViewControl`, and any
  new model classes).
- Serialization lives in **service classes**:
  - `Cdd::Cddal::Serializer` — Database → CDDAL text.
  - `Cdd::Exporters::Json` / `Yaml` / `Mermaid` — Database → other formats.
  - `Cdd::Parcel::Writer` — Database → .xlsx.
  - `Cdd::Parcel::CsvWriter` — Sheet → .csv.
- Deserialization lives in reader classes:
  - `Cdd::Cddal::Builder` (driven by the parser) — CDDAL text → Database.
  - `Cdd::Parcel::WorkbookReader` / `FlatDirReader` / `ShardedDirReader` /
    `CsvReader` — file → Database.
- Future lutaml-model migration (plan 15) will replace the field-level
  accessors with typed attribute declarations; the service-class boundary
  stays the same.

### Source-of-truth literals

- **No raw `"MDC_P###"` or `"MDC_C###"` literals** outside the registry
  files. Use `Cdd::PropertyIds::<CONST>`, `Cdd::MetaClasses::<CONST>`,
  or `Cdd::AliasTable#resolve(alias_name)`.
- The registry files are:
  - `lib/cdd/property_ids.rb` — `Cdd::PropertyIds::REGISTRY` and the
    constant-for-each-entry pattern.
  - `lib/cdd/meta_class.rb` — `Cdd::MetaClasses::REGISTRY`.
  - `lib/cdd/alias_table.rb` — built-in alias defaults.
- Code-generation for the TS editor port uses the same REGISTRY as the
  source of truth (`lib/cdd/codegen/ts.rb`).

### Design principles

- **Open/Closed.** Adding a new entity type, validator rule, exporter
  format, or Parcel sheet type = adding a new class + registration, not
  editing a switch statement.
- **DRY** without premature abstraction. Three similar lines is better
  than a wrong abstraction. Five similar lines is the threshold to extract.
- **MECE.** Every concern lives in exactly one place. No overlap, no gaps.
- **Model-driven, semantically-driven.** Classes named after domain
  concepts. Methods named after domain actions. Data flows through the
  model, not around it.
- **Frozen value objects.** Entities are constructed once, then frozen.
  Mutations go through command objects (`Database#rename_entity`,
  `Database#apply_change_request`), not in-place setters.

### Forbidden patterns

- `send` to call private methods. Make the method public or redesign.
- `instance_variable_set` / `instance_variable_get` from outside the
  owning class.
- `respond_to?` for type checks. Use `is_a?` or design the hierarchy so
  the check isn't needed.
- `require_relative` inside `lib/`.
- `double()` in specs.
- `rm -f`, `rm -rf` on files you didn't create (see global CLAUDE.md).
- Direct commits to `main`, force-push, tag pushing, AI attribution
  (see global CLAUDE.md).

### Comments

- Default to **no comments**. Only add a comment when the **why** is
  non-obvious (hidden constraint, subtle invariant, workaround for a
  specific bug, surprising behavior).
- Never explain **what** the code does — well-named identifiers do that.
- Never reference the current task, fix, or callers ("added for issue
  #123", "used by X"). That belongs in the PR description.

## Acceptance criteria

- [x] This plan is referenced in every other plan's "Conventions" section.
- [x] A new contributor reading only this plan + `00-overview.md` can
      orient themselves in the codebase.
- [x] No file in `lib/` contains `require_relative`.
- [x] No spec file contains `double(`, `instance_double(`, or
      `allow_any_instance_of(`.
- [x] No model file (`entity.rb`, `klass.rb`, `property.rb`, `unit.rb`,
      `value_list.rb`, `value_term.rb`, `relation.rb`, `view_control.rb`)
      defines `to_h`, `to_json`, `from_h`, `serialize`, or `deserialize`.

## Dependencies

- None. This is the foundational reference.

## Open questions

None. The conventions are decided.
