# frozen_string_literal: true

require "cdd"
require "pathname"
require "rspec/its"

REFERENCE_DOCS = Pathname.new(File.expand_path("../reference-docs", __dir__))
FIXTURES = Pathname.new(File.expand_path("fixtures", __dir__))

PARCEL_MAKER_XLSX = REFERENCE_DOCS.join("export_CDD_IEC62683 in ParcelMaker format.xlsx")
NUTS_XLSX         = REFERENCE_DOCS.join("parcelmaker/(ParcelMaker)example_nut.xlsx")
KAGOSHIMA_CDDAL   = REFERENCE_DOCS.join("202003-kagoshima-iec-def-sample.cddal")
LEGACY_XLS_DIR    = REFERENCE_DOCS.join("export_CDD_IEC62368 in EXCEL format")
LEGACY_SINGLE_XLS = REFERENCE_DOCS.join("export_CDD_ISO ICS in EXCEL format.xls")

RSpec.configure do |config|
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
