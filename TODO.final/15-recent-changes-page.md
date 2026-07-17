# 15 — Recent changes page (version history feed)

## Why

Every entity with multi-version history records `version_history`
metadata: version, timestamp, user, change_request_id. We surface
this per-entity (TODO 07) but never aggregate it.

Users want "what changed recently across the whole dictionary?"
Especially for standards maintainers tracking IEC CDD updates.

## What

A new page at `/d/<dict>/changes/` listing every version entry
across the dictionary, sorted reverse-chronologically. Paginated
or capped at N=200. Each row links to the entity.

## How

- File: `src/lib/recentChanges.ts` (new)
  - `recentChanges(bundle, limit?)` walks every entity, collects version_history entries, returns sorted array.
- File: `src/pages/d/[dict]/changes.astro` (new)
  - Builds the page from the bundle at build time.
  - Shows: timestamp, version, status, entity code + name (linked), change_request_id.
  - Group by month for scannability.
- File: `src/pages/d/[dict]/index.astro`
  - Add a link to /changes/ in the overview.
- File: `src/lib/siteNav.ts`
  - Add /changes/ to the per-dict nav.

## Acceptance

- `/d/iec63213/changes/` lists 80+ version entries across 28 entities, sorted newest first.
- Each row links to the entity's detail page.
- Performance: build time doesn't blow up (linear scan, sort).
- Spec: `tests/lib/recentChanges.test.ts` covering sort + grouping.

## Status

Pending.
