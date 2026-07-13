# Plan 06 — Parcel format (Excel + CSV) full parity

## Why

The Parcel Excel format is IEC 62656-1's canonical exchange format. The
`opencdd` gem must read every Parcel shape ParcelMaker 5.2.1 emits and
write xlsx that re-reads to a semantically equal Database. The format has
three on-disk variants plus CSV; the gem must handle all four.

This plan delivers ParcelMaker features F02, F03, F04, F05, F11, F12, F13,
F15, F16, F18, F21, F23, F26, F27, F29 (per
`cdd-data/specs/parcelmaker/01_features.md`). The interactive features
(F06, F07.x, F08–F10, F17) are partly Ruby (predicates) and partly editor
(JS); this plan covers the Ruby predicates.

## Scope

- `Cdd::Parcel::Metadata` — `Project` + `pcls_LOCAL` sheet content.
- `Cdd::Parcel::SheetSchema` — the 12-row header layout, default columns
  per meta-class.
- `Cdd::Parcel::Sheet` — one sheet's parsed model.
- `Cdd::Parcel::Workbook` — collection of sheets + reserved sheets.
- `Cdd::Parcel::WorkbookReader` — `.xlsx` reader (ParcelMaker default).
- `Cdd::Parcel::FlatDirReader` — flat 6-file `.xls` directory (legacy).
- `Cdd::Parcel::ShardedDirReader` — per-class sharded `.xls` subdirs
  (harvester output).
- `Cdd::Parcel::Writer` — `.xlsx` writer (caxlsx).
- `Cdd::Parcel::CsvWriter` / `CsvReader`.
- `Cdd::Parcel::Sheet.scaffold(meta_class_irdi:, parcel_id:)` — F03.
- `Cdd::Parcel::ScrapeVerifier` — diff scraped data against authoritative
  class lists (used by `harvest/`).

## Approach

### Metadata (lib/cdd/parcel/metadata.rb)

Represents the contents of the `Project` sheet:

```ruby
Cdd::Parcel::Metadata.new(
  project_id: "IEC62683",
  parcel_id:  "0112/2///62683_1",
  source_language: "en",
  translation_languages: %w[fr ja],
)
```

Plus the `pcls_LOCAL` rows: array of `(code, name)` pairs.

### SheetSchema (lib/cdd/parcel/sheet_schema.rb)

For each meta-class, the default set of property columns and their
position in the schema header. Used by `Sheet.scaffold` and by the
writer when emitting a new sheet.

Default columns per meta-class come from the ParcelMaker manual §6 and
`cdd-data/specs/parcelmaker/02_workbook_format.md` §"Schema header".
Example for CLASS (MDC_C002):

```
MDC_P001_5 (code)        MAND
MDC_P002_1 (version)     OPT
MDC_P004_1 (pref name)   MAND
MDC_P005 (definition)    MAND
MDC_P007_1 (note)        OPT
MDC_P010 (superclass)    OPT
MDC_P011 (class_type)    MAND
MDC_P013 (is_case_of)    OPT
MDC_P014 (applicable)    OPT
MDC_P015 (applicable types) OPT
MDC_P090 (imported)      OPT
MDC_P094 (applicable docs) OPT
MDC_P097 (requirement)   OPT
```

These defaults are SSOT data in `SheetSchema`; both Ruby and the TS port
read from the same spec.

### Sheet (lib/cdd/parcel/sheet.rb)

In-memory model of one Parcel sheet:

```ruby
sheet.meta_class_irdi      # MDC_C002
sheet.parcel_id            # "IEC62683"
sheet.source_language      # "en"
sheet.translation_languages
sheet.header_rows          # 5 class-header rows
sheet.schema_header_rows   # rows 6-12 with property ID + datatype + ...
sheet.data_rows            # array of DataRow
sheet.comment_rows         # rows whose col A starts with "#"
sheet.hidden_header_rows   # F21 visibility flags
sheet.find_property_column(property_id)  # column index, matched by row-6 ID
```

`sheet.scaffold(meta_class_irdi:, parcel_id:)` produces an empty Sheet
with the default schema header from SheetSchema and one empty data row.
This is F03.

### Workbook (lib/cdd/parcel/workbook.rb)

```ruby
wb.metadata           # Project + pcls_LOCAL
wb.sheets             # Array<Sheet>, including reserved
wb.sheetmap           # parsed sheetmap sheet
wb.find_sheet(type:)  # by sheet type
wb.add_sheet(sheet)
wb.dup_sheet(name)    # F16
wb.hidden_header_rows # F21
```

`Workbook.scaffold(parcel_id:, languages:, meta_classes:)` — F02 —
creates a Workbook with `Project`, `sheetmap`, `pcls_LOCAL`, and one
empty Sheet per requested meta-class.

### WorkbookReader (lib/cdd/parcel/workbook_reader.rb)

Reads `.xlsx` via `caxlsx` (or `roo` for older builds; current gemspec
has both — standardize on `caxlsx` only and drop `roo` dependency if
possible).

```ruby
db = Cdd::Database.new
Cdd::Parcel::WorkbookReader.new(path).load_into(db)
```

Algorithm:
1. Open workbook; enumerate sheets.
2. Read `Project` → `Metadata`.
3. Read `sheetmap` → register each sheet under its meta-class and
   contentno.
4. For each per-dictionary sheet: locate rows by label in column A
   (NOT by absolute index — ParcelMaker versions drift). Build a Sheet.
5. For each data row: skip if comment (col A startswith `#`). Construct
   entity of the appropriate type, populate `properties` from the
   schema-header columns.
6. Call `db.add_entity(entity)` per row.
7. Return populated db (caller calls `db.finalize!`).

### FlatDirReader (lib/cdd/parcel/flat_dir_reader.rb)

For the legacy 6-file layout: `export_{CLASS,PROPERTY,RELATION,UNIT,
VALUELIST,VALUETERMS}_<CODE>.xls`. Each file is one sheet of one meta-class
type; reader concatenates them.

```ruby
Cdd::Parcel::FlatDirReader.new(dir).load_into(db)
```

Uses `spreadsheet` gem for `.xls` (BIFF8).

### ShardedDirReader (lib/cdd/parcel/sharded_dir_reader.rb)

For the harvester output: one subdir per class, each containing its
`.xls` files. Reader walks the directory tree, applies FlatDirReader
per subdir, merges.

### Writer (lib/cdd/parcel/writer.rb)

```ruby
Cdd::Parcel::Writer.new(path).write(db, metadata:, languages:)
```

Inverse of WorkbookReader:
1. Build a Workbook by iterating entities grouped by meta-class.
2. For each group, scaffold a Sheet; fill data rows from entities.
3. Materialize `sheetmap`, `Project`, `pcls_LOCAL` from metadata.
4. Serialize to `.xlsx` via `caxlsx`.

Normalization on write:
- Set-of-refs values normalized to brace form `{a,b,c}` (per spec R09).
- ParcelMaker-variant property IDs normalized back from canonical
  (`MDC_P004` → `MDC_P004_1`) so ParcelMaker itself can re-read.
- Codes left as short form unless an entity has no supplier context.

### CsvWriter / CsvReader

CSV is the same 12-row header + data rows. Defaults: UTF-8, comma,
double-quote, no BOM. Multilingual cells use the `{(name,lang),...}`
literal form verbatim.

### Aggregate / split / Selector

Already present in `lib/cdd/parcel.rb`. Lock API:

```ruby
Cdd::Parcel.aggregate(*paths)                 # → Database
Cdd::Parcel.split(database, by: :entity_type | :root_class | :each_class | Proc)
Cdd::Parcel::Selector.new(database)           # entity selection w/ class closure
```

These cover F12 (export dictionary to separate files) when combined with
`Writer`.

### Scrape verifier

`Cdd::Parcel::ScrapeVerifier` diffs a scraped Database against an
authoritative class list (e.g. `harvest/verify/iec-*.txt`). Used by the
harvest pipeline, not directly by ParcelMaker features — keep, don't
extend.

## Parcel-specific gotchas

- **Row drift.** Schema-header row numbers vary between ParcelMaker
  versions. Match by label in column A, never by absolute index.
- **Property ID normalization.** Apply `PARCEL_VARIANT_TO_CANONICAL` on
  read; reverse on write.
- **Comment rows.** First cell startswith `#`. Skip for operations,
  preserve through round-trip.
- **Code uniqueness.** Within a sheet, codes are `KEY` (R02). Reader
  emits a warning on duplicates; doesn't drop the row.
- **Header visibility (F21).** `Workbook#hidden_header_rows` is a Set
  of row labels; reader skips hidden, writer writes them but flags with
  Excel's row-hidden attribute.
- **Multilingual cells.** `TRANSLATABLE_STRING_TYPE` cells carry
  `{(text,lang),...}` literal. Reader parses into `Languages` value
  object; writer emits literal form.

## Acceptance criteria

- [x] Reader consumes `reference-docs/export_CDD_IEC62683 in ParcelMaker format.xlsx`
      without error; entity counts match the source dictionary.
- [x] Reader consumes `reference-docs/export_CDD_IEC62368 in EXCEL format/`
      (flat-dir .xls) without error.
- [x] Reader consumes `reference-docs/parcelmaker/(ParcelMaker)example_nut.xlsx`.
- [x] Writer round-trips: read → write → read yields semantically equal
      Database (plan 12).
- [x] `Sheet.scaffold(MDC_C002, "IEC62683")` produces the expected
      default-columns list from `cdd-data/specs/parcelmaker/02_workbook_format.md`.
- [x] CSV writer emits UTF-8 with comma delimiter; re-reads via
      CsvReader to semantically equal Database.
- [x] `Parcel.split(by: :each_class)` produces N partitions, one per
      class, each self-sufficient (declared properties + their value
      lists + their units).
- [x] All specs in `spec/parcel/` green.

## Dependencies

- **Plan 03** — entity classes.
- **Plan 04** — property IDs / meta-classes.
- **Plan 05** — Database.
- Blocks **plan 12** (round-trip testing depends on read+write).

## Open questions

- **Q1.** Drop `roo` dependency in favor of `caxlsx` for `.xlsx` only?
  **Recommendation:** yes, but confirm `.xls` (BIFF8) read via
  `spreadsheet` gem covers the legacy fixtures first.
- **Q2.** For `VALUELIST` / `VALUETERMS` legacy files (which are paired),
  should the FlatDirReader infer the join, or require both files? Both
  files exist in fixtures — require both, raise on missing pair.
- **Q3.** Should we support writing `.xls` (BIFF8)? **Recommendation:**
  no — ParcelMaker 5.2.1 itself no longer writes `.xls`; only reads.
  Document as one-way.
