# 13 — Parcel (.xlsx) output

## Why

The Ruby `Opencdd::Parcel::Writer` produces IEC 62656-1 Parcel
workbooks (10 sheets, the canonical CDD exchange format). The
browser currently offers JSON, CDDAL, and source-XLS downloads per
entity, but never offers a Parcel workbook — the format the
standard mandates for inter-organization exchange.

Users with ParcelMaker, Excel-based CDD tools, or corporate CDD
pipelines need Parcel files. Today they have to scrape cdd.iec.ch
themselves.

## What

Build-time emit of one Parcel .xlsx per dictionary under
`data/<dict>/parcel/<parcel_id>.xlsx`. Browser links to it from:
1. The dictionary overview page (`/d/<dict>/`) — new "Downloads" section.
2. The dictionary about page (`/d/<dict>/about`).
3. Each entity's DownloadMenu — relabel as "Parcel (.xlsx)" grouped under "Whole dictionary".

## How

- Repo: `cdd-data/Rakefile`
  - New task: `browser:build_parcel[dict]`.
  - Loads the dict's database via `Opencdd::Reader.load_database`.
  - Calls `Opencdd::Parcel::Writer.new(db).write(File.open(path, "wb"), parcel_id: <ID>)`.
  - Writes to `data/<dict>/parcel/<parcel_id>.xlsx`.
- Repo: `opencdd.github.io`
  - `acquireFromLocal` stage already syncs `data/**` recursively — no change needed.
  - The .xlsx is large (~MB); add it to `.gitignore`? No — ship it. GitHub Pages has a 1GB site limit, ~6 dicts × 10MB = 60MB is fine.
- Repo: `opencdd.github.io/src/components/ui/DictionaryDownloads.astro` (new)
  - Renders on `/d/<dict>/` overview, after the entity browser.
  - Cards for: Parcel (.xlsx), Full JSON (database.json), Full CDDAL (when emitted).
  - Each shows file size and "what's inside".

## Acceptance

- `rake browser:build_parcel[iec63213]` produces a valid .xlsx at `data/iec63213/parcel/IEC63213.xlsx`.
- The xlsx opens cleanly in Excel/Numbers/LibreOffice.
- Round-trip: `Opencdd::Database.load_workbook(<xlsx path>)` parses it back into an equivalent Database.
- Browser `/d/iec63213/` shows a "Downloads" section with the Parcel .xlsx link.
- Spec: `spec/parcel/writer_smoke_spec.rb` validates end-to-end emit + reload for a small fixture.

## Status

Pending.
