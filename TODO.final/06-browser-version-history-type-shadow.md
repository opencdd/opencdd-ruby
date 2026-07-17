# 06 — Fix `VersionHistoryEntry` type shadow in `@opencdd/models`

## Why

The `@opencdd/models` package exports two different
`VersionHistoryEntry` types:

- `models/VersionHistory.ts` — class-backed, **camelCase** (`changeRequestId`, `isCurrent`).
- `models/jsonTypes.ts` — wire-format, **snake_case** (`change_request_id`, `is_current`).

In `models/index.ts`:

```ts
export { VersionHistory, type VersionHistoryEntry } from "./VersionHistory";
export * from "./jsonTypes"; // shadowed — VersionHistoryEntry already exported above
```

The named export shadows the wildcard re-export. So callers get the
camelCase class type, which doesn't match the JSON wire shape.

This is why `VersionTimeline.vue` declares its own local interface.

## What

Resolve the collision so consumers can import the wire type cleanly.

## How — pick one

**Option A (preferred): rename the class-backed type.**
- File: `cdd-models-ts/src/models/VersionHistory.ts`
  - Rename `interface VersionHistoryEntry` → `interface VersionHistoryClassEntry`.
- File: `cdd-models-ts/src/models/index.ts`
  - Update the named export.
- The wire `jsonTypes.VersionHistoryEntry` is now unambiguous.

**Option B: subpath export.**
- File: `cdd-models-ts/package.json`
  - Add `"./jsonTypes": { "types": "./dist/models/jsonTypes.d.ts", "import": "./dist/models/jsonTypes.js" }`.
- Callers: `import type { VersionHistoryEntry } from "@opencdd/models/jsonTypes"`.

Option A is cleaner — only one type with that name.

## Acceptance

- `import type { VersionHistoryEntry } from "@opencdd/models"` resolves to the wire-format (snake_case) type.
- `VersionTimeline.vue` drops its local interface.
- All browser specs still pass.
- The TypeScript models package itself builds clean.

## Status

Pending — sibling-repo change (`cdd-models-ts`).
