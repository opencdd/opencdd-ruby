# Implementation Proposal: Condition Grammar + lutaml-model Migration

**From:** cdd-data session 2026-07-23
**User decisions:** All 3 lutaml decisions resolved; condition grammar Option 2 approved.

## Status (2026-07-24)

| Item | Status | Where |
|------|--------|-------|
| **Item 1** — Condition grammar (ClassReference subclass) | ✅ **SHIPPED** | commit `bae0c56` on `main`, merged via PR [#17](https://github.com/opencdd/opencdd-ruby/pull/17). Released in gem v0.3.1. |
| **Item 2** — lutaml-model migration | 📋 **PLAN-ONLY** | [`19b-lutaml-model-migration.md`](19b-lutaml-model-migration.md) — Phases 2.1 & 2.2 already shipped via TODO.impl/33–35; Phases 2.3, 2.4, 2.5 remain. |

TS team: `Opencdd::Condition::ClassReference` is real API on `main`,
not a proposal. See `lib/opencdd/condition.rb:141`. The `lutaml-model`
work is the only outstanding piece.

## Item 1: Condition Grammar — ClassReference subclass (TODO 18)

### Problem

IEC 62683 stores property conditions as bare class-reference sets:
```
{0112/2///62683#ACE132}
```

`Opencdd::Condition.parse` rejects this because it expects
`<left> <op> <right>`. Current workaround: `Property#condition`
rescues `ArgumentError` and returns nil — data is lost.

### Approved approach: Option 2 (ClassReference subclass)

```ruby
module Opencdd
  class Condition
    # Existing: Condition.new(left:, operator:, right:)
    # for expressions like "class_type == {ITEM_CLASS, VALUE_CLASS}"

    class ClassReference < Condition
      # For bare sets like {0112/2///62683#ACE132}
      # Means "this property applies when the host class
      # is one of the listed IRDIs"
      attr_reader :irdis

      def initialize(irdis:)
        @irdis = Array(irdis)
      end

      def class_reference?
        true
      end

      def to_s
        irdis.size == 1 ? irdis.first : "{#{irdis.join(', ')}}"
      end
    end
  end
end
```

### Grammar

```
condition       := expression | class_reference
expression      := identifier OP (literal | set)
class_reference := irdi | set
set             := "{" element ("," element)* "}"
element         := irdi | identifier
```

### Files to change

| File | Change |
|------|--------|
| `lib/opencdd/condition.rb` | Add `ClassReference` subclass; extend `parse` to accept bare IRDI/set |
| `lib/opencdd/property.rb` | Remove the `rescue ArgumentError` — parse no longer raises |
| `spec/condition_spec.rb` | New cases: bare IRDI, bare set, mixed |
| `lib/opencdd/validator/condition_rule.rb` | Accept `ClassReference` as valid |

### Verification

1. `rake browser:build[iec62683]` — previously-rescued properties now have non-nil `condition`
2. `bundle exec rspec` — all specs pass
3. CDDAL round-trip on iec62683 — class references survive

---

## Item 2: lutaml-model Migration (TODO 16) — decisions resolved

### User decisions

1. **Per-item + single-file coexist.** Both layouts supported; per-item
   default for new work. CDDAL `include` directives allow single-file
   to reference per-item files.
2. **Default format: YAML.** JSON supported as override.
3. **Multilingual fields: nested map** in YAML/JSON
   (`preferred_name: { en: "...", de: "..." }`). Flat keys only in
   Parcel xlsx (which has its own schema).

### Phased plan (unchanged from TODO 16)

> **Full plan with all 3 decisions applied:** see
> [`19b-lutaml-model-migration.md`](19b-lutaml-model-migration.md).
> That document expands each phase with files-to-change, acceptance
> criteria, risk notes, and how each decision shows up at every layer.

| Phase | Scope | LOC delta |
|-------|-------|-----------|
| 2.1 | Add lutaml-model dep, port `Unit` (smallest entity) | +50 |
| 2.2 | Port remaining 6 entities (ValueTerm → ValueList → Property → Klass → Relation → ViewControl → Entity base) | +200 |
| 2.3 | Replace CDDAL serializer/builder with lutaml adapter; lexer/parser/racc stay | -200 net |
| 2.4 | Per-item file layout: `Database.dump_to_dir(path, format: :yaml)` + `load_from_dir(path)` | +150 |
| 2.5 | Collapse `Exporters::Json`/`Yaml` to thin wrappers | -100 net |

### Per-item layout example

```
my_dictionary/
├── _meta.yaml
├── classes/
│   ├── AAA001.yaml
│   └── AAA002.yaml
├── properties/
│   ├── ABA001.yaml
│   └── ABA002.yaml
├── units/
│   └── UAA001.yaml
├── value_lists/
│   └── ASA001.yaml
├── value_terms/
│   └── AUA001.yaml
├── relations/
│   └── ACI001.yaml
└── list_of_units/
    └── UAD001.yaml
```

### Per-item YAML example

```yaml
# classes/AAA001.yaml
irdi: "0112/2///62656_1#AAA001"
code: "AAA001"
version: "1"
revision: "01"
preferred_name:
  en: "Root class"
definition:
  en: "Top-level class for all items"
superclass_irdi: null
class_type: "ITEM_CLASS"
```

### Verification gates

1. `bundle exec rspec` — all specs pass
2. `Database.load_from_dir(db.dump_to_dir(tmp))` semantically equal to `db`
3. Each entity round-trips YAML and JSON
4. Zero `def to_h` / `def from_h` / `def to_hash` in `lib/`
5. CDDAL round-trip on oceanrunner fixture
6. `rake browser:build[iec62683]` produces semantically equal JSON
