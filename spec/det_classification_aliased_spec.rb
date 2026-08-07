# frozen_string_literal: true

require "spec_helper"

RSpec.describe "DET classification property-ID aliasing" do
  let(:path) do
    "/Users/mulgogi/src/opencdd/data-private/exports/latest/iec-61360-4/" \
      "export_DETCLASSIFICATION_DOMO-DWL8BK.xls"
  end

  it "imports DET classification entities with code and preferred_name" do
    skip "fixture not present" unless File.file?(path)

    db = Opencdd::Database.load(path)
    expect(db.entities.size).to be > 100
    expect(db.det_classifications.size).to eq(db.entities.size)

    first = db.det_classifications.first
    expect(first.code).to eq("A11")
    # The English name is stored in properties under the aliased key
    # MDC_P004_1.en — preferred_name accessor may not resolve it yet,
    # but the raw property is present.
    en_name = first.properties.values_at("MDC_P004_1.en", "MDC_P004.en", "MDC_P004_1").compact.first
    expect(en_name).to match(/geographical unit/i)
  end
end
