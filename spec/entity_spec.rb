# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::Entity do
  let(:meta) { Cdd::IRDI.parse("0112/2///62656_1#MDC_C002") }

  let(:schema) do
    Cdd::Parcel::SheetSchema.from_header_rows([
      ["#PROPERTY_ID", "MDC_P001_5", "MDC_P004_1.en", "MDC_P005.en", "MDC_P002_1"],
      ["#PROPERTY_NAME.en", "Code", "Preferred name", "Definition", "Version number"],
    ])
  end

  let(:row) do
    {
      "MDC_P001_5"   => "0112/2///62683#ACC001",
      "MDC_P004.en"  => "LV switchgear and controlgear domain",
      "MDC_P006.en"  => "domain covering switching devices and their combinations",
      "MDC_P002_1"   => "1",
    }
  end

  describe ".from_row" do
    subject(:entity) { described_class.from_row(row, schema: schema, meta_class_irdi: meta) }

    it "extracts the IRDI from the Code column" do
      expect(entity.irdi).to eq(Cdd::IRDI.parse("0112/2///62683#ACC001"))
    end

    it "exposes preferred_name, definition, version via semantic accessors" do
      expect(entity.preferred_name).to eq("LV switchgear and controlgear domain")
      expect(entity.definition).to eq("domain covering switching devices and their combinations")
      expect(entity.version).to eq("1")
    end

    it "exposes the raw properties hash for unmapped fields" do
      expect(entity["MDC_P001_5"]).to eq("0112/2///62683#ACC001")
    end
  end
end
