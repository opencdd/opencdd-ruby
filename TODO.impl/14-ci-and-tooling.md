# Plan 14 — CI and tooling

## Why

The gem has three generated artifacts that must stay in sync with their
sources: the racc-generated CDDAL parser, the code-generated TS
registries for the editor, and (per plan 13) the cddal-spec Metanorma
build. CI must run the spec suite, regenerate-and-diff these artifacts
to detect drift, and cross-validate the cddal-spec against the Ruby
registry. Without this, the implementation drifts from the docs and
from the editor port.

This plan delivers the Rakefile, the GitHub Actions workflow, and the
drift-detection scripts.

## Scope

- `Rakefile` tasks: `build`, `cddal:regen`, `generate_ts`,
  `spec:data`, `lint:registry`, `spec:snapshots`.
- `.github/workflows/ci.yml` — push/PR pipeline.
- `.github/workflows/release.yml` — tag-triggered gem release (manual).
- `bin/crosscheck-cddal-spec` — verify spec literal IDs against the
  Ruby REGISTRY (plan 13 dependency).
- Drift detection: regenerate-and-diff for racc and codegen outputs.

Not in scope: actual release automation decisions (kept manual per
the "no AI pushes tags" rule).

## Approach

### Rakefile (root)

Existing `Rakefile` is minimal. Expand it:

```ruby
require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => %i[spec lint:registry]

namespace :cddal do
  desc "Regenerate the racc parser from cddal.y"
  task :regen do
    sh "bundle exec racc lib/cdd/cddal/cddal.y -o lib/cdd/cddal/generated_parser.rb"
  end

  desc "Fail if generated_parser.rb is out of sync with cddal.y"
  task :check_regen do
    sh "bundle exec racc lib/cdd/cddal/cddal.y -o /tmp/generated_parser.rb"
    sh "diff -q lib/cdd/cddal/generated_parser.rb /tmp/generated_parser.rb"
  end
end

desc "Regenerate the editor TS registry files"
task :generate_ts do
  sh "bundle exec ruby -Ilib -e 'require \"cdd/codegen\"; Cdd::Codegen::Ts.write!(dir: \"../editor/src/models\")'"
end

namespace :lint do
  desc "Verify no raw MDC_P### / MDC_C### literals outside the registry files"
  task :registry do
    sh "bin/lint-no-raw-mdc"
  end
end

namespace :spec do
  desc "Run only the data-fixture specs ( Parcel + CDDAL round-trip )"
  task :data do
    sh "bundle exec rspec spec/parcel spec/cddal_spec.rb spec/exporters_spec.rb"
  end

  desc "Regenerate snapshot files ( reviewer-run only )"
  task :snapshots do
    sh "SNAPSHOT_REGEN=1 bundle exec rspec spec/snapshot_spec.rb"
  end
end
```

### bin/lint-no-raw-mdc

Bash script (or Ruby one-liner):

```bash
#!/usr/bin/env bash
# Fail if any raw MDC_P### / MDC_C### / EXT_P### / EXT_C### / CIM_P### literal
# appears in lib/cdd/ outside the three registry files.
set -euo pipefail
git grep -nE '"(MDC_[CP][0-9]+(_[0-9]+)?|EXT_[CP][0-9]+|CIM_P[0-9]+)"' -- 'lib/cdd/**.rb' \
  ':!lib/cdd/property_ids.rb' \
  ':!lib/cdd/meta_class.rb' \
  ':!lib/cdd/alias_table.rb' \
  && {
    echo "ERROR: raw MDC/EXT/CIM literal found outside registry files:" >&2
    exit 1
  } || true
```

### bin/crosscheck-cddal-spec

Ruby script:

```ruby
#!/usr/bin/env ruby
# Walk every .adoc under ../cddal-spec/sources/, extract every
# MDC_P### / MDC_C### / EXT_* / CIM_* literal, and verify each appears in
# the Ruby Cdd::PropertyIds::REGISTRY or Cdd::MetaClasses::REGISTRY.
require "cdd"

spec_dir = File.expand_path("../cddal-spec/sources", __dir__)
abort "#{spec_dir} not found" unless File.directory?(spec_dir)

literals = Dir.glob("#{spec_dir}/**/*.adoc").flat_map do |f|
  File.read(f).scan(/(MDC_[CP]\d+(?:_\d+)?|EXT_[CP]\d+|CIM_P\d+)/).flatten
end.uniq

unknown = literals.reject do |id|
  Cdd::PropertyIds::REGISTRY.key?(id) || Cdd::MetaClasses::REGISTRY.key?(id)
end

unless unknown.empty?
  warn "Unknown IDs referenced in cddal-spec not in Ruby registry:"
  unknown.each { |id| warn "  #{id}" }
  exit 1
end

puts "OK: #{literals.size} IDs in cddal-spec all present in Ruby registry."
```

### CI workflow (.github/workflows/ci.yml)

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ruby: ["3.1", "3.2", "3.3"]
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby }}
          bundler-cache: true
      - run: bundle exec rake cddal:check_regen
      - run: bundle exec rake lint:registry
      - run: bundle exec rake spec
      - run: bundle exec rake build

  crosscheck-spec:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: opencdd/cddal-spec
          path: cddal-spec
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bin/crosscheck-cddal-spec
        env:
          CDDAL_SPEC_DIR: cddal-spec/sources
```

Notes:
- `cddal:check_regen` fails if `generated_parser.rb` is stale relative
  to `cddal.y`. Catches "edited grammar, forgot to regen" mistakes.
- `lint:registry` enforces the no-raw-literals rule from plan 04.
- `crosscheck-spec` is a separate job because it checks out the
  cddal-spec repo (which is a sibling, not a submodule).
- The CDDAL module tests (plan 09) that need a fetcher use
  `Cdd::Cddal::Fetcher::InMemory` — no network in CI. Tests that hit
  real URLs are marked `pending: "requires network"` and skipped on CI.

### Release workflow (manual trigger)

```yaml
name: Release
on:
  workflow_dispatch:
    inputs:
      version:
        description: "Version to release (e.g., 0.2.0)"
        required: true

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bundle exec rake build
      - name: Publish to RubyGems
        env:
          RUBYGEMS_API_KEY: ${{ secrets.RUBYGEMS_API_KEY }}
        run: |
          mkdir -p ~/.gem
          echo ":rubygems_api_key: ${RUBYGEMS_API_KEY}" > ~/.gem/credentials
          chmod 0600 ~/.gem/credentials
          gem push pkg/opencdd-*.gem
```

The release is **manually triggered** by a human. Per the global
CLAUDE.md, the AI never pushes tags and never publishes releases
without explicit user approval.

### Gem release checklist

A documented runbook in `TODO.impl/14-release-runbook.md` (defer to
plan 14 follow-up):
1. Update `lib/cdd/version.rb`.
2. Update `CHANGELOG.md`.
3. Open PR titled "Release X.Y.Z".
4. Merge.
5. Manually trigger the release workflow on the merge commit.
6. Confirm the version appears on RubyGems.
7. Manually create the git tag `vx.y.z` (user only — never AI).

### Local-development tasks

```bash
bundle exec guard                # if guard-rspec is added later
bundle exec rake cddal:regen     # after editing cddal.y
bundle exec rake generate_ts     # after editing property_ids.rb
bundle exec rake spec:data       # only the data-fixture specs (fast feedback)
```

## Acceptance criteria

- [x] `bundle exec rake default` runs `lint:registry` + `spec` and
      exits non-zero on failure.
- [x] `bundle exec rake cddal:check_regen` passes when the checked-in
      parser matches; fails when stale.
- [x] `bundle exec rake generate_ts` regenerates the TS files in the
      editor repo idempotently.
- [x] `bin/lint-no-raw-mdc` passes on the current codebase.
- [x] `bin/crosscheck-cddal-spec` succeeds when cddal-spec is present;
      reports unknown IDs when it isn't.
- [x] CI workflow runs on every push and PR; required to pass before
      merge to main.
- [x] Release workflow requires manual dispatch; no automatic releases.
- [x] No AI attribution in any commit, PR, or workflow file.

## Dependencies

- **Plan 04** — registry is the lint target.
- **Plan 07** — cddal.y is the regen target.
- **Plan 13** — cddal-spec is the crosscheck target.
- **Plan 09** — InMemory fetcher must exist for offline CI.

## Open questions

- **Q1.** Add rubocop? Recommendation:** yes, with a minimal config
  that mirrors the global CLAUDE.md rules. Make it advisory in CI
  (warnings) for v1; tighten later.
- **Q2.** Should we add SimpleCov coverage reporting? Recommendation:
  yes, but as a non-gating informational job.
- **Q3.** matrix Ruby versions? Recommendation: 3.1 (minimum per
  gemspec), 3.2, 3.3. Drop 3.1 when the gemspec bumps.
