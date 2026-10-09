# frozen_string_literal: true

require "spec_helper"
require "json"

# Regression: property payloads once carried data_type twice — a string
# key from the field registry and a symbol key from the property node
# wrapper — which JSON generation rejects as a duplicate key. The
# ScenicSpots fixture is the first CDDAL dictionary whose properties
# carry MDC_P022, so it exercises the collision.
RSpec.describe Opencdd::Exporters::Json do
  before { require_fixture SCENICSPOTS }
  let(:db) { Opencdd::Cddal.parse_file(SCENICSPOTS) }

  it "round-trips a database whose properties declare data types" do
    json = described_class.new.to_json(db)
    expect { JSON.parse(json) }.not_to raise_error
  end

  it "emits exactly one data_type per property, from the parsed type" do
    json = described_class.new.to_json(db)
    tradition = JSON.parse(json).find { |e| e["code"] == "SPB003" }
    expect(tradition["data_type"]).to eq("CLASS_REFERENCE(ReligiousTradition)")
  end
end
