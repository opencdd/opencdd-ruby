# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Entity::NameSynthesizer do
  describe ".synthesize" do
    it "maps simple names to property IDs" do
      result = described_class.synthesize(["Code", "Version", "PreferredName.EN"])
      expect(result).to eq(["MDC_P001_5", "MDC_P002_1", "MDC_P004.en"])
    end

    it "preserves language suffix as lowercase" do
      result = described_class.synthesize(["Definition.EN", "ShortName.FR"])
      expect(result).to eq(["MDC_P006.en", "MDC_P005.fr"])
    end

    it "returns nil for unrecognized names" do
      result = described_class.synthesize(["Code", "UnknownColumn", "Version"])
      expect(result).to eq(["MDC_P001_5", nil, "MDC_P002_1"])
    end

    it "returns nil for empty/blank values" do
      result = described_class.synthesize(["Code", nil, "", "  "])
      expect(result).to eq(["MDC_P001_5", nil, nil, nil])
    end

    it "maps all relation-type column names" do
      names = %w[RelationType RelationDomain FunctionDomain FunctionCodomain Formula FormulaLanguage]
      result = described_class.synthesize(names)
      expect(result).to eq(%w[MDC_P200 MDC_P201 MDC_P202 MDC_P203 MDC_P204 MDC_P205])
    end

    it "maps all class-type column names" do
      names = %w[ClassType Superclass IsCaseOf ApplicableProperties ImportedProperties SubClassSelection]
      result = described_class.synthesize(names)
      expect(result.compact.size).to eq(6)
    end

    it "returns an empty array for nil input" do
      expect(described_class.synthesize([])).to eq([])
    end

    it "handles names without language suffix" do
      result = described_class.synthesize(["GUID", "DefinitionSource"])
      expect(result).to eq(["MDC_P066", "MDC_P006_1"])
    end
  end

  describe "NAME_TO_PROPERTY_ID mapping" do
    it "includes all IEC 62656-1 common column names" do
      expected_names = %w[Code Version Revision PreferredName ShortName Definition Note Remark GUID]
      expected_names.each do |name|
        expect(described_class::NAME_TO_PROPERTY_ID).to have_key(name)
      end
    end
  end
end

RSpec.describe Opencdd::Parcel::SheetSchema do
  describe "name synthesis integration" do
    let(:schema) do
      rows = [
        ["#PROPERTY_NAME.en", "Code", "Version", "PreferredName.EN", "Definition.EN", "RelationType"],
      ]
      described_class.from_header_rows(rows)
    end

    it "synthesizes columns from PROPERTY_NAME when PROPERTY_ID is absent" do
      expect(schema.size).to eq(5)
    end

    it "maps PreferredName.EN to MDC_P004.en" do
      col = schema.find_by_property_id("MDC_P004.en")
      expect(col).not_to be_nil
    end

    it "maps Code to MDC_P001_5" do
      col = schema.find_by_property_id("MDC_P001_5")
      expect(col).not_to be_nil
    end

    it "maps RelationType to MDC_P200" do
      col = schema.find_by_property_id("MDC_P200")
      expect(col).not_to be_nil
    end
  end
end
