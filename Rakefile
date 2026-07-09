# frozen_string_literal: true

require "bundler/gem_tasks"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

require "json"

task default: :spec

# ── TS codegen ──────────────────────────────────────────────────
desc "Regenerate TypeScript registry files for cdd-models-ts"
task :generate_ts do
  require "cdd"
  cdd_models_ts = ENV.fetch(
    "CDD_MODELS_TS_DIR",
    File.expand_path("../cdd-models-ts", __dir__),
  )
  unless File.directory?(cdd_models_ts)
    abort "cdd-models-ts not found at #{cdd_models_ts}. Set CDD_MODELS_TS_DIR."
  end
  Cdd::Codegen::Ts.generate_all(cdd_models_ts)
end
