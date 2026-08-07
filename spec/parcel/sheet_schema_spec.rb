# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Parcel::SheetSchema do
  let(:header_rows) do
    [
      ["#PROPERTY_ID", "MDC_P001_5", "MDC_P002_1", "MDC_P004_1.en"],
      ["#PROPERTY_NAME.en", "Code", "Version number", "Preferred name"],
      ["#DATATYPE", "STRING_TYPE", "STRING_TYPE", "TRANSLATABLE_STRING_TYPE"],
      ["#VALUE_FORMAT", "M..255", "M..10", nil],
      ["#REQUIREMENT", "KEY", "MAND", "MAND"],
    ]
  end

  describe ".from_header_rows" do
    subject(:schema) { described_class.from_header_rows(header_rows) }

    it "instantiates one Column per PROPERTY_ID cell" do
      expect(schema.size).to eq(3)
      expect(schema.columns.map(&:property_id))
        .to eq(["MDC_P001_5", "MDC_P002_1", "MDC_P004.en"])
    end

    it "exposes per-column name, datatype, value_format, requirement" do
      code_col = schema.find_by_property_id("MDC_P001_5")
      expect(code_col.name).to eq("Code")
      expect(code_col.datatype).to eq("STRING_TYPE")
      expect(code_col.value_format).to eq("M..255")
      expect(code_col).to be_key
      expect(code_col).not_to be_required

      ver_col = schema.find_by_property_id("MDC_P002_1")
      expect(ver_col.name).to eq("Version number")
      expect(ver_col).to be_required
    end

    it "supports lookup by property ID and by name" do
      expect(schema["MDC_P004.en"].name).to eq("Preferred name")
      expect(schema["Preferred name"].property_id).to eq("MDC_P004.en")
    end

    it "exposes language-specific names when present" do
      rows = [
        ["#PROPERTY_ID", "MDC_P004_1.en", "MDC_P004_1.fr"],
        ["#PROPERTY_NAME.en", "Preferred name", nil],
        ["#PROPERTY_NAME.fr", nil, "Nom préféré"],
      ]
      s = described_class.from_header_rows(rows)
      expect(s.find_by_property_id("MDC_P004.fr").name("fr")).to eq("Nom préféré")
    end

    it "normalizes non-conformant language codes (jp → ja) in column IDs" do
      rows = [
        ["#PROPERTY_ID", "MDC_P004_1.en", "MDC_P004_1.jp"],
        ["#PROPERTY_NAME.en", "Preferred name", nil],
        ["#PROPERTY_NAME.jp", nil, "推奨名"],
        ["#DATATYPE", "STRING_TYPE", "TRANSLATABLE_STRING_TYPE"],
        ["#REQUIREMENT", "MAND", "MAND"],
      ]
      s = described_class.from_header_rows(rows)
      expect(s.columns.map(&:property_id))
        .to eq(["MDC_P004.en", "MDC_P004.ja"])
      col = s.find_by_property_id("MDC_P004.ja")
      expect(col.name("ja")).to eq("推奨名")
    end
  end

  describe ".canonical_id" do
    it "normalizes jp suffix to ja" do
      expect(described_class.canonical_id("MDC_P004.jp")).to eq("MDC_P004.ja")
    end

    it "preserves standard language suffixes" do
      expect(described_class.canonical_id("MDC_P004.de")).to eq("MDC_P004.de")
    end
  end
end
