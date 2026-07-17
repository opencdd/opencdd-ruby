# 05 — Browser: typed `raw_properties` accessor

## Why

The browser currently casts `node as any` to access `raw_properties`
on the class detail page. This is because `EntityMetadata` in
`@opencdd/models` doesn't expose `raw_properties` as a typed field
even though the JSON wire format includes it on every entity.

```ts
// src/pages/d/[dict]/c/[code].astro
{(node as any).raw_properties && ( ... )}
<RawProperties properties={(node as any).raw_properties} />
```

Three call sites have this cast. Each one is a type hole.

## What

Add `raw_properties?: Record<string, string>` and `version_history?:
VersionHistoryEntry[]` (wire format) to `EntityMetadata` in the
shared `@opencdd/models` package. Then remove every `as any` cast.

## How

- Repo: `cdd-models-ts` (sibling).
- File: `src/models/jsonTypes.ts`
  - The wire `EntityMetadata` interface already has `raw_properties` — confirm and expose.
  - Add `version_history?: VersionHistoryEntry[]`.
- File: `dist/models/jsonTypes.d.ts` — regerate by building the package.
- Repo: `opencdd.github.io`.
- File: `src/lib/types.ts`
  - Re-export the wire types under clearer names if helpful.
- File: `src/pages/d/[dict]/c/[code].astro` and `EntityDetailShell.astro`
  - Drop `(node as any).raw_properties` → `node.raw_properties`.
- File: `src/components/islands/VersionTimeline.vue`
  - Drop the local `interface VersionHistoryEntry` once the wire type is importable (also TODO 06).

## Acceptance

- `npm run check` is clean with **zero** `: any` casts in entity detail pages.
- `npm run build` still passes.
- The class page still renders raw_properties correctly.
- No new runtime dependencies.

## Status

Pending — blocked on TODO 06 (which unblocks the type import).
