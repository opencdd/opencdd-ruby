# Plan 07 — CDDAL grammar (lexer + parser + AST + builder)

## Why

CDDAL is the canonical plain-text format for CDD content. It must parse
the existing fixtures (`oceanrunner.cddal`, `202003-kagoshima-iec-def-sample.cddal`)
and the wider corpus produced by the harvester and by round-tripping
Parcel xlsx. The grammar must also support the module/import extensions
in plan 09.

The grammar already exists (`lib/cdd/cddal/{lexer,parser,ast,builder,
generated_parser}.rb` + `cddal.y`). This plan locks the grammar against
the spec draft, ensures the AST nodes are sufficient for the builder and
serializer, and prepares the grammar for plan 09's import extensions.

## Scope

- `Cdd::Cddal::Lexer` — tokenizer.
- `Cdd::Cddal::Parser` + `GeneratedParser` — racc-driven parser.
- `lib/cdd/cddal/cddal.y` — the yacc grammar (source of truth).
- `Cdd::Cddal::AST::*` — node types.
- `Cdd::Cddal::Builder` — AST → Database.

Not in scope: the serializer (plan 08), the module/import system
(plan 09), the CDDAL spec document (plan 13).

## Approach

### Tokens

From `cddal.y`:

```
META_CLASS INSTANCE ALIAS IMPORT TRUE FALSE NULL
LBRACE RBRACE COLON COMMA LANGLE RANGLE DOT LPAREN RPAREN
EQEQ NEQ
STRING NUMBER DATE IRDI IDENT
```

Reserved-keyword set: `meta-class`, `instance`, `alias`, `import`,
`true`, `false`, `null`.

Identifier rules:
- `IDENT` = `[A-Za-z_][A-Za-z0-9_]*` (letters, digits, underscores; not
  leading digit).
- `IRDI` = pattern-recognized (contains `/` or `#`).
- `DATE` = `YYYY-MM-DD` (ISO 8601 calendar date).
- `STRING` = JSON-style double-quoted.
- `NUMBER` = JSON number grammar.
- Comments: `#` to end of line. (Conflict with IRDI `#` separator is
  resolved by lexer context — `#` inside a valid IRDI pattern is part
  of the IRDI; `#` elsewhere starts a comment.)

### Grammar summary

```
document        := declaration*
declaration     := meta_class_decl | instance_decl | alias_decl | import_decl
meta_class_decl := "meta-class" ident_or_irdi "{" prop_id_list "}"
instance_decl   := "instance" [IDENT] "<" ident_or_irdi "{" assignment* "}"
                |  "instance" ident_or_irdi "{" assignment* "}"
alias_decl      := "alias" IDENT ":" ident_or_irdi
import_decl     := "import" STRING [import_modifier]    # extended by plan 09
assignment      := IDENT ["." IDENT] ":" value
value           := literal | identifier_ref | set | tuple
                |   class_reference | condition | dotted_ref
literal         := STRING | NUMBER | DATE | "true" | "false" | "null"
identifier_ref  := IDENT | IRDI
set             := "{" value* "}"
tuple           := "(" value* ")"
class_reference := IDENT "(" identifier_ref ")"
condition       := identifier_ref ("==" | "!=") (literal | set)
dotted_ref      := IDENT "." IDENT
```

Plan 09 extends `import_decl` with `as IDENT` (qualified) and
`"{" IDENT* "}"` (selective). Plan 07 keeps the basic form.

### AST nodes (lib/cdd/cddal/ast.rb)

| Node | Fields |
|------|--------|
| `Document` | `declarations: Array` |
| `MetaClassDecl` | `irdi:, property_identifiers:, line:` |
| `InstanceDecl` | `name:, meta_class_ref:, assignments:, line:` |
| `AliasDecl` | `alias_name:, property_id:, line:` |
| `ImportDecl` | `url:, modifiers:, line:` (modifiers extended by plan 09) |
| `PropertyAssignment` | `identifier:, language_tag:, value:, line:` |
| `Literal` | `kind:, raw:` (`:string`, `:number`, `:date`, `:boolean`, `:null`) |
| `IdentifierRef` | `name:` |
| `Set` | `members: Array` |
| `Tuple` | `members: Array` |
| `ClassReference` | `type_name:, argument:` |
| `Condition` | `lhs:, operator:, rhs:` |
| `DottedRef` | `receiver:, name:` |

All nodes are value objects: constructors take keyword args, instances
are frozen, equality is structural.

### Builder (lib/cdd/cddal/builder.rb)

Pipeline:
1. Walk `Document#declarations` in source order.
2. Apply `alias` declarations → seed the Database's `AliasTable`.
3. Apply `meta-class` declarations → register allowed-property sets
   (merged by union for repeated IRDIs).
4. Apply `import` declarations → see plan 09. For now: skip HTTPS URLs
   with a warning, load local files by path, dedup by canonical path.
5. Apply `instance` declarations in **two passes**:
   - Pass 1: construct entities, populate `properties`. Symbolic names
     are recorded in a symbol table.
   - Pass 2: resolve cross-references (superclass, is_case_of,
     applicable_properties, etc.) via the symbol table.
6. Return the populated Database.

Resolution order for an `IdentifierRef` (per spec §"Resolution algorithm"):

1. Full IRDI → direct lookup.
2. Symbolic name → symbol table.
3. Code → `Database#find_by_code`.
4. Otherwise: emit `Cdd::Cddal::ResolutionError` (configurable: strict
   vs. warn).

Forward references are allowed because pass 2 runs after pass 1.

### Source location tracking

Every AST node carries `line:` (1-indexed) and the Lexer tracks the
source file path. The Builder attaches a `source_location:` to each
constructed Entity (`Struct.new(:file, :line)`). Used for diagnostics
in plan 10's validator and for the import graph in plan 09.

### Re-entrant parsing

`Cdd::Cddal.parse(source, database: nil)` accepts an existing Database
to merge into. This supports plan 09's import flow: parse each imported
file into the same Database.

### racc regeneration

```
bundle exec racc lib/cdd/cddal/cddal.y -o lib/cdd/cddal/generated_parser.rb
```

Rake task `cddal:regen` (plan 14). The generated file is checked in so
test environments don't need racc at install time.

## Acceptance criteria

- [ ] `Cdd::Cddal.parse_file("reference-docs/examples/oceanrunner.cddal")`
      produces 20 classes, 19 properties, 1 value list.
- [ ] `Cdd::Cddal.parse_file("reference-docs/202003-kagoshima-iec-def-sample.cddal")`
      produces the entities the Kagoshima sample encodes.
- [ ] Builder resolves symbolic names in `superclass`,
      `applicable_properties`, `is_case_of`.
- [ ] Builder resolves `CLASS_REFERENCE(...)` and `ENUM_*_TYPE(...)`
      arguments.
- [ ] Builder parses `condition: a == b` and
      `condition: a == { b, c }` into a `Cdd::Condition`.
- [ ] Forward references work: an instance may reference another
      declared later in the file.
- [ ] Comments (`#` to EOL) are skipped.
- [ ] `rake cddal:regen` regenerates `generated_parser.rb` idempotently.
- [ ] `spec/cddal_spec.rb` green.

## Dependencies

- **Plan 03** — entities.
- **Plan 04** — IRDI, PropertyIds (the builder normalizes aliases).
- **Plan 05** — Database (builder calls `add_entity`).
- Blocks **plan 08** (serializer is the inverse), **plan 09**
  (module system extends the grammar), **plan 12** (round-trip),
  **plan 13** (spec describes the grammar).

## Open questions

- **Q1.** Should the grammar allow `instance` declarations without a
  meta-class (anonymous)? The current grammar accepts both forms; the
  Kagoshima sample uses no `<` form. **Recommendation:** yes — keep
  both; the bare form means "use the document's default meta-class for
  this block" (typically `MDC_C002`).
- **Q2.** Should we support single-quoted strings? **Recommendation:**
  no — JSON double-quote is enough; single quotes add ambiguity with
  apostrophes in definitions.
- **Q3.** Should conditions support `&&` and `||`? The current grammar
  only has `==` and `!=`. ParcelMaker only emits single-equality
  predicates. **Recommendation:** defer until a real fixture needs it.
