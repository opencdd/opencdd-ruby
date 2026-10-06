# frozen_string_literal: true

require "opencdd"
require "pathname"
require "rspec/its"

# OpenCDD-authored reference material, committed in this repo.
REFERENCE_DOCS = Pathname.new(File.expand_path("../reference-docs", __dir__))
# IEC-copyright fixtures live in the private sibling repo (data-private);
# specs that need them skip when the repo is not checked out (e.g. CI).
PRIVATE_REFERENCE_DOCS = Pathname.new(File.expand_path("../../data-private/reference-docs", __dir__))
FIXTURES = Pathname.new(File.expand_path("fixtures", __dir__))

PARCEL_MAKER_XLSX = PRIVATE_REFERENCE_DOCS.join("export_CDD_IEC62683 in ParcelMaker format.xlsx")
NUTS_XLSX         = PRIVATE_REFERENCE_DOCS.join("parcelmaker/(ParcelMaker)example_nut.xlsx")
KAGOSHIMA_CDDAL   = REFERENCE_DOCS.join("202003-kagoshima-iec-def-sample.cddal")
LEGACY_XLS_DIR    = PRIVATE_REFERENCE_DOCS.join("export_CDD_IEC62368 in EXCEL format")
LEGACY_SINGLE_XLS = PRIVATE_REFERENCE_DOCS.join("export_CDD_ISO ICS in EXCEL format.xls")

module FixtureGuard
  def require_fixture(*paths)
    missing = paths.reject(&:exist?)
    return if missing.empty?

    skip "private CDD fixtures unavailable (expected in #{PRIVATE_REFERENCE_DOCS}): " \
         "#{missing.map(&:basename).map(&:to_s).join(', ')}"
  end
end

RSpec.configure do |config|
  config.include FixtureGuard
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.mock_with :rspec do |c|
    c.syntax = :expect
  end
  config.disable_monkey_patching!
  config.filter_run_when_matching :focus
  config.order = :random
end
