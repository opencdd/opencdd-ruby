# 18 — Per-entity Mermaid hierarchy diagram

## Why

The class tree sidebar is great for navigation, but a class's
"ancestor chain + subclasses + instances" is best shown as a
visual diagram. Users navigating complex hierarchies (iec61987
especially) want a quick visual.

## What

A `MermaidDiagram.astro` block on class detail pages showing the
ancestor chain (root → ... → self) and immediate subclasses +
powertype instances. Rendered server-side via Mermaid CLI at build
time, embedded as inline SVG.

## How

- File: `src/lib/mermaidTemplate.ts` (new)
  - `classHierarchyDiagram(bundle, klass)` returns a Mermaid graph definition string.
- File: `scripts/render-mermaid.ts` (new)
  - Walks every class page, generates the .mmd, runs mermaid CLI to render SVG, writes to a cache.
- File: `src/components/ui/MermaidDiagram.astro` (new)
  - Reads the cached SVG and inlines it.
- File: `src/pages/d/[dict]/c/[code].astro`
  - Insert the diagram after the EntityHero.

## Acceptance

- Every class detail page shows a hierarchy diagram.
- Diagram shows: ancestors (chained), self, subclasses, powertype instances.
- Inline SVG (no client-side JS for rendering).
- Spec: `tests/lib/mermaidTemplate.test.ts` covering graph generation.

## Status

Pending — medium effort, requires mermaid-cli integration in build.
