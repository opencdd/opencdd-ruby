---
title: The Parcel Excel format
description: The canonical Excel workbook format for exchanging CDD content — three reader layouts, one writer.
published: 2026-07-25
section: Guides
order: 50
---

Parcel is the canonical Excel workbook format for exchanging CDD
content. It's defined by IEC 62656-1 and used by ParcelMaker, IEC CDD's
bulk download endpoints, and downstream tooling. `opencdd` reads three
on-disk layouts and writes one.

## TL;DR

```ruby
# Read (auto-detects layout)
db = Opencdd::Database.load("path/to/parcel-file-or-dir")

# Write (xlsx only — .xls is read-only)
Opencdd::Parcel::Writer.new(db).write(
  "out.xlsx",
  parcel_id: "MY_DICT",
  project_id: "MY_PROJECT",
  source_language: "en",
)
```

## File extensions

| Extension | Format                                  | Read | Write |
|-----------|-----------------------------------------|:----:|:-----:|
| `.xlsx`   | Office Open XML (ParcelMaker default)   | ✅   | ✅    |
| `.xlsm`   | xlsx with macros                        | ✅   | ❌    |
| `.xls`    | OLE Compound / BIFF8 (legacy)           | ✅   | ❌    |
| `.csv`    | UTF-8 (or configured encoding)          | ✅   | ✅    |
| `.txt`    | Same as CSV with `.txt` extension       | ✅   | ✅    |
| `.cddal`  | Plain-text canonical format             | ✅   | ✅    |

`.xls` writing is intentionally unsupported — ParcelMaker itself
stopped writing `.xls` after 5.2.1; modern exchange uses `.xlsx`.

## Workbook structure

A Parcel workbook contains reserved sheets plus per-dictionary sheets.

### Reserved sheets

#### `Project`

Single-row metadata sheet:

| Column             | Example              | Notes                              |
|--------------------|----------------------|------------------------------------|
| `Project ID`       | `IEC62683`           | Identifies the project             |
| `Parcel ID`        | `0112/2///62683_1`   | Supplier-qualified parcel IRDI     |
| `Multi language`   | `en,fr,ja`           | Comma-separated language codes     |
| `Base language`    | `en`                 | Source language for translations   |

#### `sheetmap`

Authoritative index of every parcel sheet. One row per sheet:

| Column       | Example                            | Notes                          |
|--------------|------------------------------------|--------------------------------|
| `projectid`  | `IEC62683`                         |                                |
| `parcelid`   | `0112/2///62683_1`                 |                                |
| `classid`    | `0112/2///62656_1#MDC_C002##1`     | Meta-class IRDI                |
| `contentno`  | `0`                                | Index for multiple sheets/type |
| `sheetno`    | `4`                                | Excel sheet index              |
| `sheetname`  | `IEC62683_CLASS`                   | Worksheet name                 |
| `type`       | `CLASS`                            | See sheet-type constants       |
| `target`     | `` (usually empty)                 | External-parcel target         |

#### `pcls_LOCAL`

Flat list of dictionaries registered in this workbook:

| (col A) code | (col B) name              |
|--------------|---------------------------|
| `IEC62683`   | `IEC 62683 dictionary`    |

### Per-dictionary sheets

Named `<PARCEL_ID>_<TYPE>` (e.g. `IEC62683_CLASS`). TYPE is one of:

| TYPE          | Meta-class  | Content                       |
|---------------|-------------|-------------------------------|
| `DICTIONARY`  | `MDC_C001`  | Dictionary meta-info          |
| `CLASS`       | `MDC_C002`  | Class definitions             |
| `PROPERTY`    | `MDC_C003`  | Property definitions          |
| `SUPPLIER`    | `MDC_C004`  | Supplier definitions          |
| `ENUM`        | `MDC_C005`  | Value-list definitions        |
| `DATATYPE`    | `MDC_C006`  | Data-type definitions         |
| `DOCUMENT`    | `MDC_C007`  | Document definitions          |
| `UoM`         | `MDC_C009`  | Units of measurement          |
| `TERMINOLOGY` | `MDC_C010`  | Value terms (multilingual)    |
| `RELATION`    | `MDC_C011`  | Relation / function defs      |
| `VIEWCONTROL` | `EXT_C001`  | View-control definitions      |

## Parcel sheet layout

Every per-dictionary sheet follows the same 12-row header + N-row data layout.

### Class header (rows 1–5)

Anchors the sheet to its meta-class. Match by label in column A, not by
absolute row — row numbers drift between ParcelMaker versions.

| Row | Cell A label         | Cell A:G value                       |
|-----|----------------------|--------------------------------------|
| 1   | `#CLASS_ID`          | Meta-class IRDI, e.g. `MDC_C002`     |
| 2   | `#CLASS_NAME.en`     | Localized meta-class name            |
| 3   | `#SOURCE_LANGUAGE`   | Source language code, e.g. `en`      |
| 4   | `#DEFAULT_SUPPLIER`  | Supplier IRDI, e.g. `0112/2///62656_1` |
| 5   | `#DEFAULT_VERSION`   | Default version number, e.g. `1`     |

### Schema header (rows 6–12)

One column per property. Column A holds the label; columns B onwards
hold per-property metadata. Column order is NOT normative — readers
match by property ID in row 6.

| Row | Label             | Content                                       |
|-----|-------------------|-----------------------------------------------|
| 6   | `#PROPERTY_ID`    | Property IRDI (e.g. `MDC_P001_5`)             |
| 7   | `#PROPERTY_NAME.en` | Localized property name                     |
| 8   | (optional)        | Synonym / comment / definition                |
| 9   | `#DATATYPE`       | Data type token                               |
| 10  | `#UNIT`           | Unit code if applicable                       |
| 11  | `#DEFAULT_VALUE`  | Default value                                 |
| 12  | `#VALUE_FORMAT`   | IEC 61360 value-format token                  |
| 13  | `#DEFAULT_SUPPLIER` | Per-cell supplier override                  |
| 14  | `#DEFAULT_VERSION`  | Per-cell version override                   |
| 15  | `#PATTERN`        | PCRE regex                                    |
| 16  | `#REQUIREMENT`    | One of `KEY`, `MAND`, `OPT`                   |

### Data section (rows 13+)

Each row is one ontological element (one class, one property, etc.).

- **Column A**: the element's code (e.g. `AAA001`) — must be unique
  within the sheet (`#REQUIREMENT = KEY`).
- **Columns B onwards**: the value for that column's property.
- A row is a **comment row** if column A starts with `#`. Comment rows
  are skipped on read and preserved through round-trip.

## IRDI / ICID grammar

Every entity is identified by an IRDI per ISO/IEC 11179-6. Three forms:

| Form      | Example                              | When used                       |
|-----------|--------------------------------------|---------------------------------|
| Full      | `0112/2///62656_1#AAA001##1`         | Cross-dictionary references     |
| Short     | `AAA001`                             | Same-dictionary references      |
| Commented | `0112/2///62656_1#AAA001##1###note`  | Optional annotation             |

The reader resolves short forms against the sheet's `#DEFAULT_SUPPLIER`
and `#DEFAULT_VERSION` to reconstruct the full form.

## Reading Parcel files

### Auto-detect (recommended)

```ruby
db = Opencdd::Database.load("any/parcel-shaped/path")
```

The reader inspects the path and dispatches to the right strategy.

### `.xlsx` (ParcelMaker default)

```ruby
Opencdd::Parcel::WorkbookReader
  .new("export_CDD_IEC62683 in ParcelMaker format.xlsx")
  .load_into(Opencdd::Database.new)
```

Uses `caxlsx` to parse the Open XML package.

### Legacy 6-file `.xls` (BIFF8)

```ruby
Opencdd::Parcel::FlatDirReader
  .new("export_CDD_IEC62368 in EXCEL format")
  .load_into(Opencdd::Database.new)
```

Reads the six files (`export_{CLASS,PROPERTY,RELATION,UNIT,VALUELIST,
VALUETERMS}_<CODE>.xls`) and merges. Uses the `spreadsheet` gem.

### Per-class sharded dirs (harvester output)

```ruby
Opencdd::Parcel::ShardedDirReader
  .new("downloads/iec63213")
  .load_into(Opencdd::Database.new)
```

Walks the dictionary root, where each class has its own subdir holding
its `.xls` exports. Supports two on-disk layouts:
- **flat (legacy)**: `<CODE>/export_*.xls`
- **per-version**: `<CODE>/<UNID>/export_*.xls` with
  `<CODE>/_entity.json` identifying the current version's UNID

### CSV

```ruby
Opencdd::Parcel::CsvReader.new(path).load_into(db)
```

Same 12-row header + data rows. Defaults: UTF-8, comma, double-quote,
no BOM.

## Writing Parcel files

### Scaffold an empty workbook

```ruby
db = Opencdd::Database.new
db.add_dictionary(
  Opencdd::Database::Dictionary.new(
    parcel_id: "MY_DICT",
    source_language: "en",
    translation_languages: %w[fr ja],
    meta_class_irdis: %w[MDC_C002 MDC_C003 MDC_C005],
  )
)
Opencdd::Parcel::Writer.new(db).write("out.xlsx", parcel_id: "MY_DICT")
```

### Round-trip

```ruby
db = Opencdd::Database.load("input.xlsx")
Opencdd::Parcel::Writer.new(db).write("output.xlsx", parcel_id: "ROUNDTRIP")
db2 = Opencdd::Database.load("output.xlsx")
db.semantically_equal?(db2)  # => true (for non-colliding property IDs)
```

### Aggregating and splitting

```ruby
# Merge multiple Parcel sources into one Database
db = Opencdd::Parcel.aggregate("a.xlsx", "b.xlsx", "c-dir/")

# Split one Database into partitions
Opencdd::Parcel.split(db, by: :entity_type)  # one partition per type
Opencdd::Parcel.split(db, by: :root_class)   # one per root class
Opencdd::Parcel.split(db, by: :each_class)   # one per class (self-sufficient)
```

## Common gotchas

### Row drift

Schema-header row numbers vary between ParcelMaker versions. The reader
matches by label in column A, never by absolute index. If you write a
custom reader, do the same.

### Property ID normalization

ParcelMaker uses variant IDs (`MDC_P004_1`, `MDC_P005`, `MDC_P007_1`)
while IEC canonical uses base IDs (`MDC_P004`, `MDC_P006`, `MDC_P008`).
The reader normalizes variants to canonical via
`PropertyIds::PARCEL_VARIANT_TO_CANONICAL` so entity.rb reads the
canonical IDs.

### Code uniqueness

Within a sheet, codes are `KEY` (R02 validator rule). The reader emits
a warning on duplicates but does not drop the row.

### Multilingual cells

`TRANSLATABLE_STRING_TYPE` cells use the `{(text,lang),...}` literal
form in single-cell representation, or per-language columns when the
schema header declares them. The reader parses into `Languages` value
objects; the writer emits the literal form.

### Comment rows

First cell startswith `#`. Skipped for operations, preserved through
round-trip.

## What's not supported

- **`.xls` writing** — ParcelMaker 5.2.1 itself no longer writes
  `.xls`; only reads. The gem matches this.
- **External parcel linking (F19)** — referencing entities in Parcel
  workbooks not loaded into the current database. Use CDDAL imports
  instead.
- **Live CDD search (F20)** — the `cdd.iec.ch` backend is gated by AWS
  WAF; can't be reached from a library context. Use the Python
  harvester in `opencdd/data-private` to fetch first.

## See also

- IEC 62656-1 — the standard (see `reference-docs/standards/IEC62656-1 FDIS ED1.doc`)
- ParcelMaker manual — `reference-docs/normative/ParcelMaker_Manual_v5.0.0.md`
- [CDDAL syntax guide](cddal-syntax.md) — the plain-text alternative
- [Validator rules](architecture.md#validator-rules) — R01–R16
