# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

OpenCDD is an open Common Data Dictionary online resource that republishes IEC CDD
data plus additional models built on the same schema. Backed by
ISO/TC 184/SC 4/JWG 24 and IEC/SC 3D.

CDD is an ontology language that is **not** OWL/RDF or UML. Its defining feature is
**power-type modelling**: classes can be specialized by instances, and those
instances can themselves be used as classes. Any model the library builds must
preserve that two-level capability — instances-as-classes is not an edge case,
it is the central abstraction.

The **Parcel** format is the canonical exchange format for CDD, embodied as an
Excel workbook with a fixed sheet structure. The library targets Parcel as its
primary import/export surface.

## What's in this repo

The Ruby `cdd` gem is shipped — full ParcelMaker 5.2.1 functional parity
in the library layer, 572 specs green. See `README.md` for the API overview
and `TODO.full-cdd/` for per-phase plans.

The repo also contains:

- `reference-docs/` — authoritative CDD exports + ParcelMaker manuals (source
  material, do not delete).
- `downloads/` — scraped `.xls` files (one dir per dictionary).
- `harvest/` — Python scraper ecosystem (`download.py`, `discover.py`,
  `probe_*.py`, cached `tree_form_*.html`, `pages/`, `verify/iec-*.txt`).
  Fetches from `cdd.iec.ch` using headful Playwright. See
  [`harvest/README.md`](harvest/README.md) and [`DATA.md`](DATA.md).
- `specs/parcelmaker/` — the behavioral spec driving the gem.
- `TODO.full-cdd/` and `TODO.cdd-editor/` — engineering plans.

## Reference formats (in `reference-docs/`)

Two distinct layouts exist; the library must understand both.

**ParcelMaker `.xlsx`** — single workbook, 10 sheets, the canonical Parcel shape:

```
Project                 metadata
sheetmap                sheet ↔ entity-type mapping
pcls_LOCAL              local class-id bridge
<PROJ>_CLASS            class definitions
<PROJ>_PROPERTY         property definitions
<PROJ>_ENUM             enumerations / value lists
<PROJ>_TERMINOLOGY      value terms (multilingual labels)
<PROJ>_UoM              units of measurement
<PROJ>_RELATION         relationships between classes
<PROJ>_VIEWCONTROL      view-control metadata
```

Real example: `export_CDD_IEC62683 in ParcelMaker format.xlsx` (project IEC62683).

**Legacy "EXCEL format" `.xls`** — OLE-compound BIFF, **one file per entity
type**, 6 files per dictionary: `export_{CLASS,PROPERTY,RELATION,UNIT,
VALUELIST,VALUETERMS}_<CODE>.xls`. Real example: the `export_CDD_IEC62368 ...`
folder. Per-class downloads in `downloads/` only fetch 4 of these variants
(CLASS, PROPERTY, VALUELIST, VALUETERMS) — that is a scrape-time decision, not
a format constraint.

The IRDI (International Registration Data Identifier) is the canonical key for
every entity. Forms observed: `0112/2///61360_4#AAA001` (full) and `AAA001`
(short class code). The same entity can be referenced either way.

## Harvesting from cdd.iec.ch

The CDD backend is Lotus Notes Domino. There is no parcel server, no JSON
endpoint, no bulk dump. Pages are `.nsf/<form>/<UNID>` and attachments are
`.nsf/0/<UNID>/$file/<filename>`. The site is gated by AWS WAF behind CloudFront.

Hard constraints baked into `harvest/download.py`:

- **Headful Chromium only.** Headless gets 403 from WAF. Do not "optimize" by
  switching to headless.
- **In-page navigation only.** `page.request.get()` and out-of-page HTTP get 403.
  The WAF token is bound to the issuing browser client.
- **Tokens are per-page, per-class.** Each class page renders export buttons as
  `<input id="export7" onclick="return _doClick('<UNID-body-token>', ...)">`.
  The flow is: fetch class page → parse token → `?OpenDocument&Click=<token>`
  → read `<a id="download" href="...">` → follow href to capture the `.xls`.
- **Tree enumeration** comes from `Tree?ReadForm&ongletactif=1`, which returns
  inline `d.add(id, parent_id, 'label', 'TU0/<IRDI>')` calls. Parse those to
  get every class IRDI and its place in the hierarchy.
- **Must run on the user's machine.** The WAF token is bound to the issuing
  client IP and TLS fingerprint; cannot be transferred.

If you change `harvest/download.py`, run it against `iec63213` (26 classes) as
a smoke test before pointing at the larger dictionaries.

## The `cdd` gem

The library is at full ParcelMaker parity. Five layers in `lib/cdd/`:

1. **Identifiers & registries** — `irdi.rb`, `alias_table.rb`,
   `property_ids.rb`, `meta_class.rb`. Single source of truth for every
   property ID (`Cdd::PropertyIds::REGISTRY`) and meta-class IRDI
   (`Cdd::MetaClasses::REGISTRY`). No raw `"MDC_P###"` / `"MDC_C###"`
   string literals outside these files.
2. **Domain entities** — `entity.rb`, `klass.rb`, `property.rb`,
   `relation.rb`, `unit.rb`, `value_list.rb`, `value_term.rb`,
   `view_control.rb`. Frozen value objects. (Never name a class `Class`;
   the IEC entity type is `Cdd::Klass`.)
3. **Database & traversal** — `database.rb` (in-memory store + finalize!),
   `effective_properties.rb` (powertype-aware walker),
   `class_tree.rb`, `composition_tree.rb`, `relation_tree.rb`.
4. **Formats** — `parcel/` (all Parcel-format readers + writer + CSV:
   `WorkbookReader` for single .xlsx, `FlatDirReader` for flat .xls
   directories, `ShardedDirReader` for per-class sharded subdirs),
   `cddal/` (plain-text canonical format with racc-generated parser).
   The `.xls` format IS Parcel (IEC 62656-1) — there is no separate
   `Excel` namespace.
5. **Validation & utilities** — `validator/` (R01–R15 rules),
   `instance_rule.rb` (M1→M0 expansion), `guid.rb`, `structured_values.rb`,
   `exporters/` (JSON/YAML/Mermaid).

### Conventions that override any default instinct

- Ruby `autoload` declared in the immediate parent namespace's file.
  `lib/cdd/parcel.rb` declares `autoload :WorkbookReader,
  "cdd/parcel/workbook_reader"` etc. No `require_relative` inside
  library code.
- One concern per class — MECE. Adding a new entity type means adding a new
  model class + reader, not editing a switch statement.
- Persistence is downstream — the in-memory model is canonical.
- Do not delete or "clean up" any file in `reference-docs/` or `downloads/` —
  those are source material, not derived artifacts.

### Commands

```bash
bundle exec rspec                          # full suite (607 specs)
bundle exec rspec spec/database_spec.rb    # one file
bundle exec rspec spec/ -e "drop_dictionary"  # one example
bundle exec rake build                     # build pkg/cdd-*.gem
bundle exec racc lib/cdd/cddal/cddal.y -o lib/cdd/cddal/generated_parser.rb
```

### Audit checklist (Phase 2)

Every ParcelMaker feature F01–F30 maps to either ✅ (shipped in the gem),
✅+Editor (shipped in Ruby, planned for the OpenCDD Editor web app), or
❌ (explicitly out of scope). See `TODO.full-cdd/13-audit-and-docs.md` for
the full matrix.

The OpenCDD Editor (Phase 3) is the next deliverable — a static-site
TypeScript web app that mirrors the Ruby gem's model and exposes
ParcelMaker's interactive flows in a browser. Plans are in `TODO.cdd-editor/`.

**Phase 3 status (2026-06-24)**:
- 3.1 project scaffold — shipped (Vite + React + TS + Tailwind + Vitest).
- 3.2 TS model port — shipped (IRDI, Entity, Klass, Property, Unit,
  ValueList, ValueTerm, Relation, ViewControl, AliasTable, MetaClass,
  ClassType and PropertyDataTypeElement value objects).
- 3.3 CDDAL port — shipped (Lexer, Parser, AST, Serializer, Builder,
  DatabaseSerializer). Round-trips the OceanRunner fixture.
- 3.4 Validator port — shipped (Runner + all 13 Ruby rules R01–R14,
  including Database-dependent R02/R08/R10/R14, and the R14
  composition-cycle check via `compositionHierarchyAcyclic`).
- Database shipped (`editor/src/models/Database.ts`) with idempotent
  `finalize()` (guarded by `finalized` flag), `merge()`, `renameEntity()`,
  `removeEntity()`, `propertiesOf()`, semantic equality. `addEntity`
  keeps code/type indexes in sync when overwriting a duplicate IRDI.
- 3.5 Parcel sheet schema model — shipped (`canonicalParcelId`,
  `ParcelMetadata`, `SheetSchema`, `Sheet`, `Workbook`). Pure-TS, no
  SheetJS yet — that's Phase 3.5b.
- 3.5+ Exporters — shipped (`JsonExporter`, `YamlExporter`,
  `MermaidExporter`, `CsvWriter`). Browser-friendly ports of the Ruby
  exporters; hand-rolled minimal YAML emitter (no js-yaml runtime dep).
- 3.6 Zustand stores shipped — `databaseStore`, `historyStore`,
  `selectionStore`, `validationStore`, `uiStore`, `fileStore`. Mutation
  command pattern; single-owner rule (only `databaseStore` mutates
  Database). localStorage-backed `uiStore`.
- 3.8a tree walker ports — shipped: `ClassTree`, `RelationTree`,
  `CompositionTree`, `EffectiveProperties`. All with specs.
- 3.8b utility ports — shipped: `Guid`, `InstanceRule`,
  `StructuredValues` (7 parser/serializer pairs). All with specs.
- Audit fixes from the deep architecture review:
  - F1–F6: Builder DRY, AliasTable collision warn, Entity.type cache,
    finalize idempotency, shared `codePropertyIdFor`, addEntity index splice.
  - F11–F15: shared `referenceKinds` module (memoized
    REFERENCE_VALUE_KINDS), typed-collection return types on Database,
    SSOT literals (no raw `"MDC_P###"` / `"MDC_C###"` outside the
    registry), `asEntityIrdi`/`asPropertyIrdi` helpers.
  - F29–F35: `parseStringList` delimiter unwrap, shared
    `entityConstructors` map, `ClassType` value object.
  - F36–F40: exporter parity fixes — `JsonExporter.compact()` no
    longer strips empty arrays (Ruby `Hash#compact` parity);
    PropertyNode emits `condition` and `data_element_type`; new
    `PropertyDataTypeElement` value object; `Property.condition` /
    `Property.dataElementType` accessors. See
    `TODO.cdd-editor/26-exporter-parity-fixes.md`.
  - F43–F48 (round-5): validator message parity via shared
    `rubyInspect` helper (Ruby `.inspect` semantics — `"nil"`,
    `'"foo"'`); memoized `Property.condition` /
    `Property.dataElementType`; shared `byEntityCode` sort helper
    deduplicating Json.ts and Mermaid.ts; new `ValueFormat` value
    object + 7th StructuredValues parser/serializer pair; new
    StructuredValues round-trip invariant suite. See
    `TODO.cdd-editor/27-validator-parity-round5.md`.
- Phase 3.14 static browser site shipped (3.14a–c) + Tier 1 audit
  fixes (B1,B2,B3,B5,B6,B7,B8,B11,B12,B15) + Tier 2 audit fixes
  (B19–B24) + Tier 3 audit fixes
  (B27,B28,B30,B31,B33,B37–B39,B42) + Tier 4 audit fixes
  (B47–B55: URL `?tab=` sync, document title, ErrorBoundary,
  NotFoundPage, dropped `view_control` route segment, component
  tests, `aria-current`, two-pane persistent-tree layout, modern
  design-system overhaul) + Tier 5 audit fixes
  (B56–B65: `/` keyboard shortcut to focus search via
  `useSlashToFocus`, tree-node tooltip via `title=`, skip-to-content
  link via `SkipToContent` (WCAG 2.4.1), `prefers-reduced-motion`
  audit, one-click copy IRDI via `CopyButton` + `IrdiPill`
  (`aria-live="polite"` feedback), section deep-linking via
  `sectionSlug` + `SectionTitle anchor` + `useScrollToHash`,
  `EntityHero` redesign with gradient backdrop + IRDI pill +
  version/revision/dates pills + definition subtitle, SearchBar
  clear (×) button with re-focus, PropertyTable sticky header,
  search match highlighting via `highlightMatches` wrapping matches
  in `<mark>`) + Tier 6 audit fixes
  (B66–B78: per-entity-type `EntityIcon` glyphs, WCAG tree keyboard
  navigation via `useTreeKeyboardNav` with roving tabindex, sticky
  `TableOfContents` with `IntersectionObserver` scroll-spy,
  `DictionaryBundle.propertiesForUnit` reverse index + unit-detail
  "Used by" section, expand-all/collapse-all tree bulk controls,
  `/d/:dict/about` metadata page, about-page heading hierarchy fix
  (h1→h2 to avoid duplicate h1), about-page counts derived from
  `bundle.byType` runtime ground truth instead of `registry.counts`
  build-time snapshot) + Tier 7 audit fixes
  (B79–B89: **entity-type metadata SSOT**
  (`data/entityTypeMeta.ts` — one record per type drives labels,
  route segments, badge tones, and tab membership; replaces five
  parallel declarations across `routes.ts`, `entityTabs.ts`,
  `primitives.tsx`, `EntityCountChips.tsx`, and
  `DictionaryAboutPage.tsx`), **bundle-derived count chips**
  (`EntityCountChips` accepts an optional `bundle` prop and reads
  `bundle.byType` when present — completes B78's SSOT fix for the
  layout header), **value-list term lookup bug fix** (B89:
  `ValueListBody` was round-tripping through `codeFromIrdi` +
  `byCode`; now uses `entities.get(irdi)` directly like every other
  IRDI reference), **shared `EntityLinkList` component** (DRYs the
  repeated link-list pattern across six call sites in detail pages),
  **`EntityLink` bundle self-resolution** (optional `bundle` prop
  auto-resolves `type` and `fallbackLabel` from the bundle)) + Tier 8
  audit fixes
  (B91–B94: **property ↔ value-list cross-linkage** (B92: Ruby
  exporter emits `value_list` IRDI on `PropertyNode`; fixed
  `Database#value_list_of` to resolve via
  `parsed_data_type.value_list_identifier` — was broken for
  CDDAL-sourced data; browser renders "Value list" link on property
  detail + "Used by (N)" reverse section on value-list detail via
  new `propertiesForValueList` index), **declared-property reverse
  index** (B93: `propertiesByClassIrdi` pre-built index replaces
  O(N) scan per class page), **bundle plumbing to
  RelationBody/ValueTermBody** (B94: round-7's `EntityLink`
  self-resolution now fires on relation domain lists and value-term
  → value-list links), **dead shim file cleanup** (B91: deleted
  three untracked files from earlier rounds — `routes.ts`,
  `entityTabs.ts`, `DictionaryPage.tsx`)) + Tier 9 audit fixes
  (B98: global cross-type search via `DictionaryBundle.search`
  linear scan + `useGlobalSearch` debounced hook (120ms) +
  `GlobalSearch` WAI-ARIA header combobox (ArrowUp/Down, Enter,
  Escape, `aria-activedescendant`); dictionary-scoped via new
  `ActiveDictionaryContext` consumed by the Header;
  B99: pretty data-type chip via `parseDataType` discriminated
  union (`simple` / `measure` / `enum` / `class_reference` /
  `unknown`) + `DataTypeChip` component that hyperlinks the
  value-list name inside `ENUM_*_TYPE(...)` and the class code
  inside `CLASS_REFERENCE(...)` through three-step resolution
  (preferredIrdi → parsed identifier → byCode fallback, with type
  filter to prevent wrong-typed links);
  B100: `EntityHero` accepts optional `sourceDocument`, renders as
  accent-tone Badge, auto-wraps URLs in `<a target="_blank"
  rel="noreferrer noopener">`;
  B101: `relationsForCodomainClass` reverse index + "Referenced
  as codomain" section on ClassDetailPage (symmetric to the
  existing Relations section, reusing a shared `RelationRows`
  helper);
  B107: `UsedByField` shared component DRYs the `Used by (N)`
  Field + EntityLinkList pattern across PropertyBody /
  ValueListBody / UnitBody;
  B102: `useDictionary` exposes a stable `retry` callback backed
  by an `attempt` counter that re-runs the effect; PageShell
  renders a "Try again" button on the error card when `onRetry`
  is provided) + Tier 10 audit fixes
  (B108: dedicated `ValueTermTable` component — 3-column
  scannable table (enumeration_code | preferred_name |
  definition) matching `PropertyTable`'s visual treatment;
  value-list detail lifts terms out of the Details Card into
  their own deep-linkable `#terms` section via the new
  `renderAfter` slot on `EntityDetailPage` (DRY-safe:
  `EntityDetailBody` now accepts an optional `afterCard`
  ReactNode);
  B109: `GlobalSearch` active-row auto-scroll — `useEffect`
  watches `activeIndex` and calls
  `scrollIntoView({ block: "nearest" })` via the existing
  deterministic `resultId(listboxId, i)` row id; mirrors the
  pattern already used in `ClassTree.tsx` for tree focus;
  B110: `tests/GlobalSearch.test.tsx` — WAI-ARIA combobox
  behavior suite (disabled state, results render, no-matches
  status, ArrowDown advances active row, Enter navigates,
  Escape closes, clear button resets + re-focuses); wraps the
  component in `ActiveDictionaryContext.Provider` +
  `MemoryRouter` so the suite owns both dependencies;
  B111: `tests/helpers/factories.ts` — builder-pattern test
  factories (`makeClass`, `makeProperty`, `makeValueList`,
  `makeValueTerm`, `makeUnit`, `makeRelation`, `resetFactories`,
  `makeBundle`, `makeBundleSlice`); each builder accepts
  `Partial<T>` overrides applied over the type-required minimum;
  convention: IRDIs use `"test#CODE"` so `codeFromIrdi` extracts
  the expected short code; `makeBundle` constructs a real
  `DictionaryBundle` (full reverse-index surface);
  `makeBundleSlice` returns a shallow `Pick<DictionaryBundle,
  "entities" | "byCode">` for tests that only need lookup) +
  Tier 11 audit fixes
  (B112: **Cmd+K / Ctrl+K shortcut to focus global search** —
  the industry convention every modern web app ships; new
  generic `useKeyboardShortcut(matcher, handler, { enabled,
  ignoreEditable })` hook centralizes editable-element detection
  (INPUT/TEXTAREA/SELECT/contentEditable) and `defaultPrevented`
  guard; `useSlashToFocus` rewritten as a thin wrapper over the
  new hook; new `usePlatform` SSOT module exporting
  `isApplePlatform()` + `platformModifierLabel()` (returns `⌘`
  on Apple, `Ctrl` elsewhere) — used by `Header` to render both
  `⌘K` primary hint and `/` secondary hint with platform-aware
  label;
  B113: **print stylesheet** layered via Tailwind `print:`
  variants on chrome (header/footer/sidebar get `print:hidden`;
  `Card` gets `print:break-inside-avoid`; copy buttons and
  `SectionTitle`'s anchor `#` link get `print:hidden`;
  `EntityHero` gradient flattens via `print:bg-none
  print:shadow-none`; `PageShell`'s main gets
  `print:max-w-none print:px-0 print:py-0`); small `@media print`
  block in `styles/index.css` for the three rules Tailwind
  variants can't express — visible link URLs via `a[href]:after
  { content: " (" attr(href) ")" }` (skipped for internal
  anchors), `h1/h2/h3 { break-after: avoid }`, color-scheme
  override;
  B114: **tree property count badges** — subtle count badge at
  the right edge of each tree row when the class has at least
  one declared property; new
  `DictionaryBundle.declaredPropertyCount(classIrdi): number`
  reads the existing `declaredPropertiesByClassIrdi` index
  without materializing the array; `ClassTree` accepts an
  optional `propertyCounts?: (irdi: string) => number` prop,
  renders nothing when count is 0 or prop is absent (no layout
  shift); `DictionaryLayout` threads a stable
  `propertyCounts={(irdi) => bundle.declaredPropertyCount(irdi)}`
  callback;
  B115: **shared `useScrollActiveIntoView` hook** DRYs the
  `scrollIntoView({ block: "nearest" })` pattern shared by
  ClassTree and GlobalSearch; `GlobalSearch` migrates to the
  hook (replacing the inline round-10 scroll effect);
  `ClassTree` intentionally keeps its inline focus-and-scroll
  effect because focus and scroll are two distinct concerns
  there — migrating would force the scroll-only hook to take a
  second side-effect, breaking single-responsibility;
  B116: **spec coverage expansion** — `useKeyboardShortcut.test.tsx`
  (5 specs: matcher fires, not when target is editable, not
  when `enabled` is false, fires from editable when
  `ignoreEditable` is false, supports modifier chords),
  `useScrollActiveIntoView.test.tsx` (4 specs: scrolls on
  activeId change, noop when disabled, noop when resolver
  returns null, noop when activeId is null/undefined),
  `ClassTree.test.tsx` extended with 3 specs for property count
  badges: renders badge when count > 0, omits when 0, omits
  when `propertyCounts` prop absent) —
  read-only static-hosted CDD browser in
  `browser/`, rebuilt with a 2026-grade modern UX rather than a
  cdd.iec.ch look-alike. Vite + React + TS + Tailwind; shares the
  editor's model layer via a path alias (`@opencdd/models`).
  **Architecture**: `DictionaryLayout` owns the dictionary fetch and
  renders a persistent two-pane shell (sticky `ClassTree` sidebar +
  `<section aria-label="Dictionary content">` with an `<Outlet />`).
  Detail pages consume the bundle via `useDictionaryContext()`
  (wraps `useOutletContext`) so the tree stays mounted across
  detail navigation. URL is the source of truth for both tab
  (`?tab=`) and highlighted class (derived from
  `useMatch("/d/:dict/c/:code")`).
  **Design system**: custom Tailwind tokens (`ink-*` warm dark,
  `sand-*` warm light, `accent-*` indigo), `Card` / `SectionTitle`
  / `Badge` / `EntityBadge` / `Skeleton` / `EmptyState` /
  `CopyButton` / `IrdiPill` / `EntityHero` / `SkipToContent`
  primitives in `components/ui/primitives.tsx`. Foundational text
  helpers (`sectionSlug`, `highlightMatches`) in
  `components/text.tsx`. Skeleton loaders, ErrorBoundary
  with `getDerivedStateFromError`, real 404 surface, fade-in /
  slide-up animations, sticky sidebar, mobile tree toggle,
  `prefers-reduced-motion` override.
  Data pipeline is `rake browser:sample` /
  `rake browser:build[<dict>]` → static JSON under
  `browser/public/data/`. `DictionaryBundle` owns derived indexes
  (`subclassesOf`, `classesDeclaringProperty`, `instancesOf`,
  `relationsForClass`, `relationsForCodomainClass`,
  `propertiesByClassIrdi`, `propertiesForValueList`,
  `propertiesForUnit`) — all built by a single generic
  `buildReverseIndex` helper — plus an in-memory `search(query)`
  method for the header global-search combobox, and cycle-safe
  walkers (`ancestorChainOf`, `effectivePropertiesOf` — ports
  Ruby's `Cdd::EffectiveProperties`). `PageShell` unifies
  loading/error/not-found scaffolding across all pages including
  the dictionary index. `MetadataFields` renders the shared
  cdd.iec.ch metadata surface (synonyms, note, remark, description,
  example, source_document, guid, version, revision, time_stamp,
  dates). Class detail page surfaces ancestor-chain breadcrumb
  (Root › Parent › Self), powertype Instances (reverse of
  `is_case_of`), Composition (`sub_class_selection`), Relations
  (where the class is in `domain`), source attribution on Inherited
  properties, and a `?expand=<code>` back-link that auto-expands
  every ancestor of the target class in the tree. `EntityCountChips`
  renders all 7 entity-type counts on the dictionary index.
  `codeFromIrdi` in `browser/src/data/irdi.ts` is the SSOT for
  short-code extraction. Ruby `Cdd::Exporters::Json` extended with
  the shared `entity_payload` helper. 301 browser tests passing. See
  `TODO.cdd-editor/28-static-browser-site.md`,
  `TODO.cdd-editor/29-browser-site-audit-findings.md`,
  `TODO.cdd-editor/30-browser-audit-round-2.md`,
  `TODO.cdd-editor/31-browser-audit-round-3.md`,
  `TODO.cdd-editor/32-browser-audit-round-4.md`,
  `TODO.cdd-editor/33-browser-audit-round-5.md`,
  `TODO.cdd-editor/34-browser-audit-round-6.md`, and
  `TODO.cdd-editor/35-browser-audit-round-7.md`, and
  `TODO.cdd-editor/36-browser-audit-round-8.md`.
- Codegen: `rake generate_ts` regenerates `PropertyIds.generated.ts`
  and `MetaClasses.generated.ts` from the Ruby REGISTRY. These files
  are checked in.
- 607 Ruby specs + 578 editor tests + 301 browser tests passing
  (1486 total). Phase 1 import pipeline shipped: `Cdd::Parcel.aggregate`
  (merge multiple parcel paths), `Cdd::Parcel.split` (partition by
  `:entity_type`, `:root_class`, `:each_class`, or Proc),
  `Cdd::Parcel::Selector` (entity selection with class-hierarchy
  closure), `Cdd::Database#apply_change_request` (upsert + removals).
  Back-compat aliases removed — `Cdd::Excel` namespace eliminated,
   readers renamed to MECE names (`WorkbookReader`, `FlatDirReader`,
  `ShardedDirReader`). CDDAL serializer fixed for non-ASCII UTF-8
  values, control-character escaping, and backslash quoting.
  Phases 3.5b, 3.7, 3.8 UI, 3.9, 3.10, 3.11, 3.12,
  3.13, 3.14d–f are pending — see
  `TODO.cdd-editor/20-remaining-work-master.md` for the prioritized
  roadmap and audit register.
- **2026-06-25 demo data**: `rake browser:build[<dict>]` builds any
  scraped dictionary into the static browser. Currently populated:
  oceanrunner (40) + iec63213 (26) + iec61360-7 (52) + iec63508 (151)
  + iec61360 (574) + iec62683 (1855) + iec61987 (11831) =
  **14,529 entities** across 7 dictionaries. Run `cd browser && npm run dev`
  to serve at `http://localhost:5173`.
- **2026-07-17 data pipeline additions** (see `TODO.final/`):
  - `rake browser:build_parcel[<dict>]` — emit a Parcel .xlsx via
    `Opencdd::Parcel::Writer`. Output at `data/<dict>/parcel/<parcel_id>.xlsx`.
  - `rake browser:build_versions[<dict>]` — emit per-version JSON
    via `Opencdd::Parcel::VersionedReader` + `Opencdd::Exporters::Json#payload_for`.
    Output at `data/<dict>/versions/<code>/<unid>.json`.
  - `rake browser:build_all_parcel` — batch Parcel emit across all dicts.
- **2026-07-17 public API additions**:
  - `Opencdd::Cddal::Serializer#emit_entity(entity)` — single-entity CDDAL.
  - `Opencdd::Exporters::Json#payload_for(entity, database: nil)` — registry-dispatched per-entity payload (no case/when).
  - `Opencdd::Parcel::VersionedReader#versions_for(code)`, `#load_version(code, unid)`.
  - `Opencdd::EntityDiff.between(a, b)` + `#added` / `#removed` / `#changed`.
- **Phase 2 (lutaml-model migration) NOT started**: tracked in
  `TODO.full-cdd/16-lutaml-model-migration.md`. This is the major
  remaining architectural work — migrate entities to `Lutaml::Model`
  classes, add per-item YAML/JSON file layout, replace hand-rolled
  CDDAL serializer. Blocked on user decision re: file-format default
  (YAML vs JSON) and multilingual field shape (nested vs flat).
- **Audit findings 2026-06-25**: see
  `TODO.full-cdd/17-architecture-audit-2026-06-25.md`. Key items:
  A1 (Condition grammar rejects class-reference sets — interim
  workaround in `Property#condition`), A2 (dead `format_set` in
  CDDAL serializer), A3 (Parcel writer normalizes "001"→"1"),
  A4 (entity.rb vs REGISTRY property ID discrepancies — needs
  user decision).

## Working with the Python scrapers

The scraper ecosystem lives in `harvest/` (see
[`harvest/README.md`](harvest/README.md) for the full guide). Quick reference:

- `harvest/download.py` is the main harvester. `--dictionary <key>` selects
  from `DICTIONARIES`. Idempotent: existing files on disk are skipped,
  progress is in `downloads/<dict>/_state.json`.
- `harvest/discover.py` and `harvest/probe_*.py` are one-off investigation
  scripts; keep them but don't extend them.
- `harvest/tree_form_*.html`, `harvest/discovery.json`, `harvest/pages/*.html`,
  and the per-class `downloads/<dict>/<CLASS>/_page.html` files are diagnostic
  captures — useful for figuring out token shapes without re-hitting the server.
- `harvest/verify/iec-*.txt` are user-authored authoritative class lists used
  to verify scrape coverage.

## Things that look unused but are not

`harvest/tree_form_*.html`, `harvest/discovery.json`, `harvest/pages/*.html`,
and the per-class `_page.html` files are diagnostic source material for
reverse-engineering the Domino page shapes. They are not generated artifacts.
Do not delete them.
