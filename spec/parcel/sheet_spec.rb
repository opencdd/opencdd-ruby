# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Parcel::Sheet do
  def build_rows
    [
      ["#CLASS_ID:=MDC_C002"],
      ["#CLASS_NAME.en:=Class meta-class"],
      ["#SOURCE_LANGUAGE:=en"],
      ["#PROPERTY_ID", "MDC_P001_5", "MDC_P004_1.en", "MDC_P010"],
      ["#PROPERTY_NAME.en", "Code", "Preferred name", "Superclass"],
      ["#DATATYPE", "STRING_TYPE", "TRANSLATABLE_STRING_TYPE", "ICID_STRING"],
      ["#REQUIREMENT", "KEY", "MAND", nil],
      [nil, "0112/2///62683#ACC001", "LV switchgear and controlgear domain", nil],
      [nil, "0112/2///62683#ACC010", "LV switchgear and controlgear blocks of properties", "0112/2///62683#ACC001"],
      [nil, nil, nil, nil],
    ]
  end

  describe ".from_rows" do
    subject(:sheet) { described_class.from_rows(build_rows.each, name: "TEST_CLASS") }

    it "captures the metadata directives" do
      expect(sheet.metadata.meta_class_code).to eq("MDC_C002")
      expect(sheet.metadata.class_name).to eq("Class meta-class")
      expect(sheet.type).to eq(:class)
    end

    it "captures the column schema" do
      expect(sheet.schema.size).to eq(3)
      expect(sheet.schema["MDC_P001_5"].name).to eq("Code")
      expect(sheet.schema["MDC_P010"].name).to eq("Superclass")
    end

    it "captures data rows indexed by property ID" do
      expect(sheet.rows.size).to eq(2)
      first = sheet.rows.first
      expect(first["MDC_P001_5"]).to eq("0112/2///62683#ACC001")
      expect(first["MDC_P004.en"]).to eq("LV switchgear and controlgear domain")
    end

    it "drops trailing empty rows" do
      expect(sheet.rows.last["MDC_P001_5"]).to eq("0112/2///62683#ACC010")
    end

    it "preserves a row even when only some columns are populated" do
      second = sheet.rows[1]
      expect(second["MDC_P010"]).to eq("0112/2///62683#ACC001")
    end

    it "exposes meta_class_irdi" do
      expect(sheet.meta_class_irdi).to eq(Opencdd::IRDI.parse("MDC_C002"))
    end
  end

  describe "integration with reference workbook" do
    subject(:sheet) do
      reader = Opencdd::Parcel::WorkbookReader.new(PARCEL_MAKER_XLSX.to_s)
      workbook = reader.read_workbook
      workbook.sheets.find { |s| s.name == "IEC62683_CLASS" }
    end

    it "parses the meta-class" do
      expect(sheet.meta_class_code).to eq("MDC_C002")
      expect(sheet.type).to eq(:class)
    end

    it "parses at least 360 data rows" do
      expect(sheet.rows.size).to be >= 360
    end

    it "parses the schema including the Superclass column" do
      superclass = sheet.schema.columns.find { |c| c.name.to_s =~ /superclass/i }
      expect(superclass).not_to be_nil
      expect(superclass.property_id).to eq("MDC_P010")
    end

    it "captures the IRDI and preferred name of the first row" do
      first = sheet.rows.first
      expect(first["MDC_P001_5"]).to eq("0112/2///62683#ACC001")
      expect(first["MDC_P004.en"]).to eq("LV switchgear and controlgear domain")
    end
  end
end
