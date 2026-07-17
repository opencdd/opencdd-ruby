# 07 — Browser: time-travel content swap

## Why

The VersionTimeline currently only shows metadata for each version.
Clicking "View this version" should load that version's actual
content (property values, relationships, definition) and render the
page as-of that point in time.

This is the headline feature of the version-history work.

## What

When the user clicks a non-current version in VersionTimeline:

1. The page fetches `/<dict>/entity/<code>/v/<version>.json` (TODO 08 builds these).
2. The page applies the `[data-time-travel]` filter treatment.
3. A sticky banner appears: "Viewing version 002 (superseded, 2022-07-25). [Return to current]".
4. The entity hero, properties, and metadata all show the historical values.
5. The page URL updates to `?v=<version>` for shareability.

## How

- File: `src/components/islands/VersionTimeline.vue`
  - Wire the "View this version" button to fetch + dispatch.
  - On click: emit an event with the version UNID.
- File: `src/components/islands/TimeTravelBar.vue` (new)
  - Sticky banner shown when `[data-time-travel]` is active.
  - "Return to current" button → clears state.
- File: `src/layouts/DictionaryLayout.astro`
  - Add `<TimeTravelBar client:load />` near the top of `<main>`.
- File: `src/pages/d/[dict]/c/[code].astro` (and other entity pages)
  - On `?v=<version>` query, SSR-fetch the historical JSON during build? No — runtime fetch is fine for a static site.

### SSR vs runtime

Two paths:
- **SSR per version**: build generates `/d/<dict>/c/<code>?v=002` static page. Cleanest, but multiplies build size by average version count (~1.4× for iec61987 → ~50k pages).
- **Runtime fetch**: page loads current, JS fetches historical JSON, swaps content. No build cost; graceful degradation.

Pick **runtime fetch** for now. SSR can come later if SEO demands.

## Acceptance

- Click "View v002" on `/d/iec63213/c/KEA012` → page shows v002 content + sticky banner.
- URL becomes `/d/iec63213/c/KEA012?v=c7b602fc...`.
- "Return to current" → reverts to current.
- Direct-loading `?v=...` works on page load.
- Graceful fallback if the version JSON is missing (e.g. oceanrunner).
- No `: any` in new code.

## Status

Pending — blocked on TODO 08 (per-version JSON build).
