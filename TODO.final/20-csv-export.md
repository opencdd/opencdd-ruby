# 20 — CSV export option in DownloadMenu

## Why

JSON is great for tooling, CDDAL is great for diffs, but
spreadsheet users (most CDD consumers) want CSV. They have to
write a JSON-to-CSV converter themselves today.

## What

Add a CSV option to DownloadMenu that emits a flat spreadsheet
row per (entity, field) pair — one row per `raw_property` entry.
Useful for analysts who want to slice the data in Excel.

## How

- File: `src/lib/csvEmitter.ts` (new)
  - `emitEntityCsv(entity)` returns CSV text with columns: `irdi, code, type, property_id, language, value`.
  - Multilingual keys split into multiple rows.
- File: `src/components/islands/DownloadMenu.vue`
  - Add CSV option with file icon.
- File: `tests/lib/csvEmitter.test.ts` (new)

## Acceptance

- CSV download from any entity detail page produces a valid CSV.
- File opens cleanly in Excel/Numbers.
- Spec covers multilingual splitting and special-character escaping.

## Status

Pending.
