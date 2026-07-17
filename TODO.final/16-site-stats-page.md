# 16 — Site-wide stats page

## Why

The homepage lists dictionaries with counts. The about page shows
per-dict counts. But there's no "stats overview" — total entities
across all dicts, version distribution, top properties, etc.

This is great landing-page material and helps users grasp scale.

## What

A `/stats/` page (and a stats card on `/`) showing site-wide
metrics: total entities, total versions, multi-version entities,
top-N value lists by size, dictionary comparison.

## How

- File: `src/lib/siteStats.ts` (new)
  - Aggregates all bundles into a single stats object.
- File: `src/pages/stats.astro` (new)
  - Renders the stats. Sparklines for version distribution. Bar chart for entity counts per dict.
- File: `src/pages/index.astro`
  - Add a single "X total entities across Y dictionaries" hero stat with link to /stats/.

## Acceptance

- `/stats/` shows: 21,853 total entities, 38,428 version entries, 8,868 multi-version entities.
- Each metric has a one-sentence explanation.
- Page is responsive + dark-mode-aware.
- Build time under 5s extra.

## Status

Pending.
