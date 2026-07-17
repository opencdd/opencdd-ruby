# 17 — Recently viewed entities (localStorage)

## Why

Users navigating between entities (e.g., comparing a property with
its value list, then back to a class) have no "back" beyond the
browser's history. A "recently viewed" rail in the sidebar would
speed up common exploration flows.

## What

A `RecentlyViewed.vue` island in the right sidebar that records
the last 10 entity detail pages the user has visited. Persists
across sessions via localStorage.

## How

- File: `src/components/islands/RecentlyViewed.vue` (new)
  - Reads/writes `localStorage["opencdd:recent"]` (JSON array of `{ irdi, code, name, type, href, ts }`).
  - Listens to `astro:page-load` event (fires on view transition).
  - Renders a compact list with code + name + relative timestamp.
  - "Clear" button.
- File: `src/layouts/DictionaryLayout.astro`
  - Add `<RecentlyViewed client:idle />` to the right sidebar (above TableOfContents on entity pages, or as a separate sidebar slot).

## Acceptance

- Visiting `/d/iec63213/c/KEA012/` then `/d/iec63213/c/KEA001/` shows both in RecentlyViewed.
- List persists across page reload.
- "Clear" empties the list.
- Spec: `tests/components/RecentlyViewed.test.ts` covering add/dedupe/clear.

## Status

Pending.
