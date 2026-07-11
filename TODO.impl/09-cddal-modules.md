# Plan 09 — CDDAL module / import system (split-file format)

## Why

The user's explicit requirement #4: CDDAL must support a split-file format
where one `.cddal` file can cross-reference entities declared in another
`.cddal` file by IRDI, with the **file location** resolved from a local
path **or** a URL. The current implementation has a stub `import STRING`
that skips HTTPS and only opens local files; no cycle detection, no
qualified imports, no selective imports, no source-location tracking, no
pluggable fetcher.

This plan delivers a module/import system informed by best practices from
similarly-syntaxed languages.

## Inspirations (and what we adopt from each)

| Language | What we adopt | What we reject |
|----------|---------------|----------------|
| **Python** | `from "x" import { y, z }` selective form; `as` rename | Implicit `sys.path` magic; module-level `__init__.py` |
| **Rust** | Explicit dependency graph; cycles are hard errors; visibility (`pub`) is opt-in | Lifetime / borrow syntax; trait system |
| **Go** | URL imports work natively; module cache; deterministic resolution | Mandatory `go.mod` for every file |
| **ES6** | `import { a, b } from "url"` brace syntax; named exports | Default exports; runtime dynamic import |
| **Terraform** | Pluggable source schemes (path, URL, registry) | Module input/output variables (CDDAL has no value-level modules) |
| **C/C++ #include** | (nothing) — textual-only inclusion is too fragile | Macro expansion; order-dependent compilation |

Key design choices, derived:

1. **Default import = textual inclusion of named declarations.** A bare
   `import "path"` brings in every named declaration from the target as
   if inlined. Symbolic names from imports are merged into the importing
   document's symbol table.
2. **Selective and qualified imports are opt-in.** When name collisions
   matter, the author writes `from "path" import { Foo, Bar }` or
   `import "path" as alias` and qualifies references.
3. **URL imports work out of the box** with a pluggable fetcher.
   `Net::HTTP` is the default; tests use an in-memory fetcher.
4. **The dependency graph is explicit and acyclic.** A cycle raises a
   `Cdd::Cddal::ImportError` with the full cycle path.
5. **Source location is tracked end-to-end.** Every entity knows which
   file (and line) it came from — including transitively-imported ones.
6. **Resolution is deterministic.** Same input + same fetcher cache =
   same Database. Build tools can rely on this.

## Scope

- New grammar productions in `cddal.y` (extensions to `import_decl`).
- New AST node types in `lib/cdd/cddal/ast.rb`.
- Path / URL resolver: `Cdd::Cddal::Resolver`.
- Pluggable HTTP fetcher: `Cdd::Cddal::Fetcher` with `NetHttp` and
  `InMemory` implementations.
- Dependency graph + cycle detection in the Builder.
- Source location tracking on every Entity.
- Selective and qualified import semantics in the symbol table.

Not in scope: versioning of remote modules (open question Q1), cryptographic
integrity pins (open question Q2), private vs. public declaration modifiers
(open question Q3).

## Approach

### Grammar extension (lib/cdd/cddal/cddal.y)

```
import_decl
  : IMPORT STRING                              { bare textual inclusion }
  | IMPORT STRING AS IDENT                     { qualified: alias.Name }
  | FROM STRING IMPORT LBRACE import_list RBRACE  { selective }
  ;

import_list
  : IDENT                                      { result = [val[0]] }
  | import_list COMMA IDENT                    { result = val[0] + [val[2]] }
  ;
```

New tokens: `AS`, `FROM`. Both reserved as keywords.

### Concrete examples

```cddal
# (1) Bare — textual inclusion. Symbolic names from lib.cddal merge in.
import "https://cdd.opencdd.org/dictionaries/rec20-units.cddal"

# (2) Qualified — names from units.cddal accessible as `units.Metre`.
import "../base/units.cddal" as units

# (3) Selective — only the named declarations are pulled in.
from "../base/vehicles.cddal" import { Vehicle, Boat }

# (4) Combined selective + qualified (allowed for ergonomics).
from "../base/vehicles.cddal" import { Vehicle as V, Boat }
```

Forms (1)–(3) cover the 90% case. Form (4) handles collisions.

### Resolution rules

`Resolver.new(base_path:, search_path:, fetcher:)` resolves a module
specifier:

| Specifier | Resolution |
|-----------|------------|
| `./path.cddal` or `../path.cddal` | Relative to the importing file's directory. |
| `/abs/path.cddal` | Absolute filesystem path. |
| `path.cddal` (bare) | Searched in `search_path` (defaults to `["."]` and `$CDDAL_PATH` split on `:`). |
| `http://...` / `https://...` | Fetched via `fetcher`. Cached by URL in the current run. |
| `file:///abs/path.cddal` | File URI; resolves to absolute path. |
| anything else | `Cdd::Cddal::ImportError`. |

The Resolver returns a canonical key (absolute path or normalized URL)
used for dedup: the same module imported twice loads only once.

### Fetcher abstraction

```ruby
module Cdd::Cddal::Fetcher
  def fetch(url) → String  # returns the file contents
end

class Cdd::Cddal::Fetcher::NetHttp
  def initialize(cache_dir: ENV.fetch("CDDAL_CACHE", Dir.tmpdir), offline: false)
  def fetch(url) → String
end

class Cdd::Cddal::Fetcher::InMemory
  def initialize(map = {})   # { url => source }
  def fetch(url) → String or raise
end
```

`offline: true` skips network and serves only from cache — used in CI
(plan 14). The InMemory fetcher is for tests.

Caching: HTTP responses are cached to `cache_dir/<sha256(url)>.cddal`
with the URL and ETag in sidecar metadata. Re-fetch sends
`If-None-Match`; on 304 the cache is used. TTL: 24h default,
configurable.

### Builder integration

`Cdd::Cddal::Builder` accepts a `resolver:` and `fetcher:`. The build
pipeline becomes:

1. Parse the root document into AST.
2. Walk declarations in source order. On `ImportDecl`:
   - Resolve the URL via `resolver`.
   - If canonical URL already in `@loaded_modules`, skip (dedup).
   - Otherwise: fetch source, parse, recursively build into the
     **same** Database with the same resolver and fetcher.
   - Record `(canonical_url, parent_url)` edge in the dependency graph.
3. After all imports resolve, apply aliases, meta-classes, instances.
4. Cycle check: depth-first traversal of the dependency graph. On
   cycle, raise `ImportError` with the full edge path.
5. Apply selective and qualified import semantics to the symbol table.

### Symbol scoping

- **Bare import**: every named declaration in the imported module
  becomes accessible by its symbolic name in the importing document.
  Conflicts (same name from two modules) raise `ResolutionError`.
- **Qualified import** (`import "x" as p`): names accessible as
  `p.Name`. The unqualified name is not in scope (avoids accidental
  collision).
- **Selective import** (`from "x" import { Foo }`): only `Foo` is
  accessible; other names from the module are not loaded.
- **Selective + rename** (`from "x" import { Foo as F }`): only `F`
  is accessible.
- **IRDIs are always global**. An entity reference by full IRDI
  resolves regardless of import scope. This is the cross-file
  cross-reference primitive.

This mirrors Python's semantics closely, with the addition that IRDIs
act as a global fallback (Python has no equivalent).

### Source location tracking

Every Entity carries `source_location: Struct.new(:file, :line, :column)`.
For imported entities, `:file` is the canonical URL/path of the imported
module, not the importer. The validator (plan 10) and diagnostics use
this; round-trip via Parcel preserves the file the entity came from
even when serialized through a single .xlsx.

### Idempotency and re-entrance

`Cdd::Cddal.parse(source, database:, resolver:, fetcher:)` parses into
the given database. Combined with dedup, this means a module imported by
multiple parents is parsed exactly once, and its entities are added
exactly once. The Database's `add_entity` is itself idempotent on IRDI.

### Worked example

A two-file project:

```cddal
# boats.cddal
meta-class MDC_C002 { code preferred_name superclass class_type applicable_properties }
instance Boat < MDC_C002 {
  code: AAA010
  preferred_name.en: "Boat"
  superclass: UNIVERSE
  class_type: ITEM_CLASS
}
```

```cddal
# main.cddal
import "./boats.cddal"
instance OceanRunner30 < MDC_C002 {
  code: BBB010
  superclass: Boat   # cross-file reference by symbolic name
}
```

Building `main.cddal` yields a Database with two classes, where
`OceanRunner30.parent.code == "AAA010"`. The Boat entity's
`source_location.file` points to `boats.cddal`.

### URL example

```cddal
import "https://cdd.opencdd.org/dictionaries/iec61360-7.cddal"
```

Build behavior:
- If `fetcher.offline?`, raise `ImportError` (or warn and continue
  if `strict: false`).
- Otherwise fetch via Net::HTTP; cache to `cache_dir`.
- Parse and merge into the Database.

The opencdd.github.io static site (separate effort) will host the
canonical reference dictionaries at this URL. Until then, the fetcher
is exercised by the test suite against locally-served fixtures.

## Public API

```ruby
resolver = Cdd::Cddal::Resolver.new(
  base_path: File.dirname(main_file),
  search_path: [".", File.expand_path("~/cdd-libs")],
)
fetcher = Cdd::Cddal::Fetcher::NetHttp.new(offline: ENV["CI"] ? true : false)

db = Cdd::Cddal.parse_file(
  main_file,
  resolver: resolver,
  fetcher: fetcher,
)
```

For tests:

```ruby
fetcher = Cdd::Cddal::Fetcher::InMemory.new(
  "https://example.test/units.cddal" => File.read(fixture_path),
)
db = Cdd::Cddal.parse(source, fetcher: fetcher)
```

## Acceptance criteria

- [ ] Existing bare `import "path"` semantics preserved — no regression
      on OceanRunner fixture (which has one HTTPS import that's currently
      skipped).
- [ ] `from "x" import { Foo }` pulls in only `Foo`.
- [ ] `import "x" as p` makes `p.Foo` resolve and bare `Foo` not resolve.
- [ ] `from "x" import { Foo as F }` renames.
- [ ] URL imports work via Net::HTTP fetcher; cache survives across
      builder instances in the same process.
- [ ] Cycle detection raises `Cdd::Cddal::ImportError` with the cycle
      path in the message.
- [ ] Every Entity has a `source_location` with `file` and `line`.
- [ ] `Cdd::Cddal::Fetcher::InMemory` allows specs to test imports
      without network.
- [ ] `strict: false` mode warns and continues instead of raising on
      unresolved imports / missing modules.
- [ ] Idempotent: building the same root file twice produces identical
      Databases.
- [ ] New spec file: `spec/cddal/modules_spec.rb`.

## Dependencies

- **Plan 07** — grammar and Builder; this plan extends both.
- **Plan 05** — Database (entity identity across files).
- **Plan 03** — Entity `source_location` field.
- Blocks **plan 13** (spec describes the module system).

## Open questions

- **Q1. Versioned modules.** Should `import "url" version "1.2"` pin a
  specific release? **Recommendation:** defer — first land unversioned,
  add versioning when a real consumer needs it.
- **Q2. Integrity pins.** Should `import "url" sha256 "..."` allow
  callers to assert the fetched content matches a hash? Useful for
  reproducibility. **Recommendation:** yes, follow-up. Same shape as
  Nix's `fetchurl`.
- **Q3. Selective export modifiers.** Should declarations have
  `pub`/`priv` visibility (Rust-style)? **Recommendation:** no — every
  declaration is importable. Namespacing via selective import handles
  encapsulation.
- **Q4. Registry-style modules.** Should there be a
  `cdd://dictionaries/iec61360-7` scheme that resolves through a
  registry (like npm or crates.io)? **Recommendation:** no — URLs are
  fine. Registries add governance overhead.
- **Q5. Workspace files.** Should we support a `cddal.toml` workspace
  manifest that declares module roots and search paths? Useful for
  multi-file projects. **Recommendation:** defer — a single
  `$CDDAL_PATH` env var covers the immediate need.
