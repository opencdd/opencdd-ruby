# 14 — Per-dictionary downloads section on overview page

## Why

Today, the dictionary overview page (`/d/<dict>/`) has the entity
browser but no "take this data with you" surface. Parcel + JSON +
CDDAL downloads live nowhere. Users have to know to look at the
about page or guess URLs.

## What

A dedicated `DictionaryDownloads.astro` section on `/d/<dict>/`
showing every format the user can pull for the whole dictionary.

## How

- File: `src/components/ui/DictionaryDownloads.astro` (new)
  - Renders only when at least one format is available.
  - Cards for:
    - Parcel (.xlsx) — TODO 13
    - Full JSON (`<dict>/database.json`)
    - Per-version JSON directory (`<dict>/versions/`) when present
  - Each card: format name, file size (build-time computed), short description, "Download" / "View" button.
- File: `src/pages/d/[dict]/index.astro`
  - Insert `<DictionaryDownloads dict={dict!} bundle={bundle} />` after the entity browser.
- File: `src/lib/dictionaryDownloads.ts` (new)
  - Pure helpers for file existence/size lookup at build time.

## Acceptance

- `/d/iec63213/` shows a "Downloads" section listing all available formats.
- Each link is correct and the file is downloadable.
- Section is hidden on dicts with no extras (graceful degradation).
- No `: any` in new code.

## Status

Pending — blocked on TODO 13.
