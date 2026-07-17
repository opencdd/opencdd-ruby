# 19 — Keyboard navigation for version timeline

## Why

The VersionTimeline renders a vertical list of version entries.
Mouse users can click "View this version" / "Diff vs current".
Keyboard users currently have to Tab through every link in every
entry — there's no concept of "next version" / "previous version".

WCAG: keyboard nav is required for accessibility.

## What

- ArrowUp / ArrowDown move focus between version entries.
- Enter activates "View this version".
- "d" activates diff (when available).
- "/" focuses the entry search (if added).
- `role="listbox"` semantics on the timeline, `role="option"` on entries.

## How

- File: `src/components/islands/VersionTimeline.vue`
  - Add `tabindex` and `onKeydown` handlers.
  - Track `activeIdx` separately from `expanded`.
  - Apply `aria-activedescendant` pattern.
- Spec: `tests/components/VersionTimeline.test.ts` (new) covering keyboard interactions.

## Acceptance

- Keyboard-only user can navigate the timeline.
- Screen reader announces the active version.
- Mouse interactions unchanged.

## Status

Pending.
