# 11 — Autoload audit

## Why

Every Ruby file under `lib/opencdd/` must be autoloadable from its
parent namespace's file. Files not autoloaded are orphans — they
compile but never load, which silently breaks features.

The CLAUDE.md rule is explicit: "Ruby `autoload` declared in the
immediate parent namespace's file."

## What

Walk `lib/opencdd/**/*.rb` and verify every `.rb` file has a
matching autoload entry in its parent namespace's file.

## How

- Script (one-off, no need to keep):
  ```bash
  for f in $(find lib/opencdd -name "*.rb"); do
    rel=${f#lib/}
    name=$(basename "$f" .rb)
    parent=$(dirname "$f")
    parent_file="lib/$(dirname "${f#lib/opencdd/}").rb"
    # Check if parent file autoloads this name
    grep -q "autoload :#{camelize $name}" "$parent_file" || echo "MISSING: $rel → $parent_file"
  done
  ```

- Add missing autoload entries to the immediate parent namespace's
  file (create the file if it doesn't exist).

## Acceptance

- The audit script reports zero missing autoloads.
- Every new file added by TODOs 01-04 has its autoload entry.
- `bundle exec rspec` passes.

## Status

Pending — run after TODOs 01-04 land so we catch all new files.
