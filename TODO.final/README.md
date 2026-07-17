# TODO.final — Remaining Work Master Plan

## TODO index (all rounds)

### Round 1 (TODOs 01-12) — Version history + per-entity emit
| # | File | Status |
|---|------|--------|
| 01 | [per-entity-cddal-emit.md](01-per-entity-cddal-emit.md) | ✅ done |
| 02 | [per-entity-json-emit.md](02-per-entity-json-emit.md) | ✅ done |
| 03 | [version-aware-reader.md](03-version-aware-reader.md) | ✅ done |
| 04 | [entity-diff-engine.md](04-entity-diff-engine.md) | ✅ done |
| 05 | [browser-typed-raw-properties.md](05-browser-typed-raw-properties.md) | ✅ done |
| 06 | [browser-version-history-type-shadow.md](06-browser-version-history-type-shadow.md) | ✅ done |
| 07 | [browser-time-travel-content-swap.md](07-browser-time-travel-content-swap.md) | ✅ done |
| 08 | [browser-per-version-json-build.md](08-browser-per-version-json-build.md) | ✅ done (iec63213) |
| 09 | [browser-diff-view.md](09-browser-diff-view.md) | ✅ done |
| 11 | [autoload-audit.md](11-autoload-audit.md) | ✅ done (spec-enforced) |
| 12 | [spec-coverage.md](12-spec-coverage.md) | ✅ done |

### Round 2 (TODOs 13-21) — Parcel output + site improvements
| # | File | Status |
|---|------|--------|
| 13 | [parcel-output.md](13-parcel-output.md) | ✅ done |
| 14 | [dictionary-downloads-section.md](14-dictionary-downloads-section.md) | ✅ done |
| 15 | [recent-changes-page.md](15-recent-changes-page.md) | ✅ done |
| 16 | [site-stats-page.md](16-site-stats-page.md) | ✅ done |
| 17 | [recently-viewed.md](17-recently-viewed.md) | ✅ done |
| 18 | [per-entity-mermaid-hierarchy.md](18-per-entity-mermaid-hierarchy.md) | pending — needs mermaid-cli build integration |
| 19 | [keyboard-nav-timeline.md](19-keyboard-nav-timeline.md) | ✅ done |
| 20 | [csv-export.md](20-csv-export.md) | ✅ done |
| 21 | [docs-update.md](21-docs-update.md) | pending |

## Final status (2026-07-16, end of round 2)

**Yes — Parcel output works end-to-end.** `rake browser:build_parcel[iec63213]` emits `data/iec63213/parcel/IEC63213.xlsx` (101 KB), downloadable from `/d/iec63213/` via the new DictionaryDownloads section.

### Ruby gem (opencdd-ruby)
- 881 specs passing.
- New public API:
  - `Opencdd::Cddal::Serializer#emit_entity(entity)`
  - `Opencdd::Exporters::Json#payload_for(entity, database:)` — registry dispatch, no case/when
  - `Opencdd::Parcel::VersionedReader#versions_for` / `#load_version`
  - `Opencdd::EntityDiff.between(a, b)` + `Change` struct
- Code-quality spec enforces autoload invariant for every `lib/opencdd/**/*.rb`.
- Zero `send` / `instance_variable_*` / `respond_to?` / `require_relative` / internal `require` in lib/.

### Data pipeline (cdd-data)
- `rake browser:build_parcel[<dict>]` — Parcel .xlsx emit (build-time, via Ruby).
- `rake browser:build_versions[<dict>]` — per-version JSON emit (80 files for iec63213).
- `rake browser:build_all_parcel` — batch Parcel emit across all dicts.

### Browser (opencdd.github.io)
- **205 vitest tests passing** (was 185 → +20: entityDiff, recentChanges, csvEmitter).
- **21,539 pages built clean** in 44s.
- New components: `VersionTimeline.vue` (with keyboard nav), `VersionDiff.vue`, `DownloadMenu.vue` (JSON/CDDAL/CSV + cdd.iec.ch link), `RecentlyViewed.vue`, `VersionHistorySection.astro`, `DictionaryDownloads.astro`.
- New libs: `cddalEmitter.ts`, `csvEmitter.ts`, `entityDiff.ts`, `recentChanges.ts`, `siteStats.ts`.
- New pages: `/stats/` (site-wide), `/d/<dict>/changes/` (version feed), `/d/<dict>/` (now with Downloads section).
- Downloads: per-entity (JSON/CDDAL/CSV from any detail page), per-dictionary (Parcel .xlsx from overview).
- Time travel + diff view from round 1 still intact.

## Open follow-ups

- **TODO 18 — Per-entity Mermaid**: needs mermaid-cli integration at build time.
- **TODO 21 — Docs update**: CLAUDE.md / README / docs/ haven't been refreshed for the new surface.
- **Per-version xls scraping**: current scraper captures only current-version xls; historical content time-travel shows metadata-only.
- **Build all dicts' Parcel files**: only `iec63213` has been run through `rake browser:build_parcel`. The other 5 dicts + oceanrunner need the same before deploy.

## Final status (2026-07-16)

**Ruby gem (opencdd-ruby)**:
- 881 specs passing (added 31 across TODOs 01–04 + code-quality spec)
- New public API:
  - `Opencdd::Cddal::Serializer#emit_entity(entity)` — per-entity CDDAL emit
  - `Opencdd::Exporters::Json#payload_for(entity, database:)` — registry-dispatched per-entity payload
  - `Opencdd::Parcel::VersionedReader#versions_for(code)` / `#load_version(code, unid)` — historical version access
  - `Opencdd::EntityDiff.between(a, b)` — structured diff with `#added` / `#removed` / `#changed`
- Code-quality spec now enforces the autoload invariant for every `lib/opencdd/**/*.rb` file
- Zero `send` / `instance_variable_set/get` / `respond_to?` / `require_relative` / internal `require` in lib/

**TS package (cdd-models-ts)**:
- Resolved `VersionHistoryEntry` type shadow — class-backed renamed to `VersionHistoryClassEntry`, wire-format `VersionHistoryEntry` now unambiguous

**Browser (opencdd.github.io)**:
- 193 vitest tests passing (added 8 in entityDiff)
- 21,884 pages built clean (0 errors)
- New components: `VersionTimeline.vue`, `VersionDiff.vue`, `DownloadMenu.vue`, `VersionHistorySection.astro`
- New libs: `cddalEmitter.ts`, `entityDiff.ts`
- Zero `: any` casts in entity detail pages
- Time-travel UI: click "View this version" → fetches per-version JSON → applies `[data-time-travel]` archival treatment → URL `?v=<unid>` for shareability
- Diff view: modal with unified/split modes, color-coded added/removed/changed

**Data pipeline (cdd-data)**:
- New rake task `browser:build_versions[dict]` emits per-version JSON via `VersionedReader` + `payload_for`
- 80 version JSON files emitted for iec63213 (28 multi-version entities × 2-3 versions each)

## Open follow-ups

1. **TODO 10** — source XLS archive hosting. Needs a size-budget decision (per-entity zips × 21k entities ≈ 1-2 GB). Recommend: only emit for multi-version entities, link to cdd.iec.ch for the rest.
2. **Historical xls scraping** — current scraper captures only the current version's .xls exports. Extending it to capture historical xls would unlock full content time-travel (not just metadata).
3. **Build all dicts' versions** — only `iec63213` has been run through `rake browser:build_versions`. Other dicts need the same treatment before deploy.
4. **Per-version content swap** — the UI fetches the JSON and shows metadata, but doesn't yet rewrite the visible entity fields. Currently shows an amber "metadata-only" notice when historical content isn't available.

## Dependency graph

```
01 → 02 → 04 → 09 (diff view consumes per-entity emit + diff engine)
              ↓
              07 (time travel uses per-version JSON)

03 → 08 (version-aware reader enables per-version JSON build)
     ↓
     07

05 → 06 (typed raw_properties unblocks type-shadow fix)

11 → all Ruby work (autoload audit catches missing entries early)

10 standalone (cross-repo: cdd-data zip emit + browser link)

12 final pass after all features land
```
