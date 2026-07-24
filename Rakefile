# frozen_string_literal: true

require "bundler/gem_tasks"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require "json"

# Default: run specs + registry lint.
task default: %i[spec lint:registry]

# ── CDDAL parser regeneration ───────────────────────────────────
namespace :cddal do
  desc "Regenerate the racc parser from cddal.y"
  task :regen do
    sh "bundle exec racc lib/opencdd/cddal/cddal.y -o lib/opencdd/cddal/generated_parser.rb"
  end

  desc "Fail if generated_parser.rb is out of sync with cddal.y"
  task :check_regen do
    tmp = ENV.fetch("CDDAL_REGEN_TMP", "/tmp/opencdd_generated_parser.rb")
    sh "bundle exec racc lib/opencdd/cddal/cddal.y -o #{tmp}"
    unless system("diff -q lib/opencdd/cddal/generated_parser.rb #{tmp}")
      warn "ERROR: lib/opencdd/cddal/generated_parser.rb is stale."
      warn "  Run `bundle exec rake cddal:regen` and commit the result."
      exit 1
    end
  end
end

# ── TS codegen ──────────────────────────────────────────────────
desc "Regenerate TypeScript registry files for cdd-models-ts"
task :generate_ts do
  # Placeholder: the actual codegen lives in Opencdd::Codegen::Ts and
  # writes to the sibling editor/cdd-models-ts repo. Invoke it
  # directly when the target directory is available.
  puts "TODO: invoke Opencdd::Codegen::Ts"
end

# ── Lint ────────────────────────────────────────────────────────
namespace :lint do
  desc "Verify no raw MDC_P### / MDC_C### literals outside the registry files"
  task :registry do
    ruby "bin/lint-no-raw-mdc"
  end
end

# ── Spec subsets ────────────────────────────────────────────────
namespace :spec do
  desc "Run only the data-fixture specs (Parcel + CDDAL + exporters)"
  task :data do
    sh "bundle exec rspec spec/parcel spec/cddal_spec.rb spec/exporters_spec.rb spec/cddal/modules_spec.rb"
  end
end
