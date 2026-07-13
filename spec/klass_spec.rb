# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Klass do
  let(:meta) { Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002") }

  let(:schema) do
    Opencdd::Parcel::SheetSchema.from_header_rows([
      ["#PROPERTY_ID", "MDC_P001_5", "MDC_P010_1", "MDC_P011", "MDC_P013", "MDC_P014", "MDC_P090", "MDC_P016"],
      ["#PROPERTY_NAME.en", "Code", "Superclass", "Class type", "Is case of", "Applicable properties", "Imported properties", "Sub class selection"],
      ["#DATATYPE", "STRING_TYPE", "ICID_STRING", "STRING_TYPE", "ICID_STRING", "ICID_STRING", "ICID_STRING", "ICID_STRING"],
    ])
  end

  let(:row) do
    {
      "MDC_P001_5" => "0112/2///62683#ACC002",
      "MDC_P010_1" => "0112/2///62683#ACC001",
      "MDC_P011"   => "CATEGORICAL_CLASS",
      "MDC_P013"   => "0112/2///62683#ACC099",
      "MDC_P014"   => "0112/2///62683#ACE001 0112/2///62683#ACE002",
      "MDC_P090"   => "0112/2///62683#ACE003",
      "MDC_P016"   => "0112/2///62683#ACC050",
    }
  end

  subject(:klass) do
    described_class.from_row(row, schema: schema, meta_class_irdi: meta)
  end

  its(:irdi) { should eq(Opencdd::IRDI.parse("0112/2///62683#ACC002")) }
  its(:code) { should eq("ACC002") }

  describe "class_type" do
    it "reads MDC_P011 and parses the value" do
      expect(klass.class_type.to_s).to eq("CATEGORICAL_CLASS")
    end

    it "is cached" do
      first = klass.class_type
      second = klass.class_type
      expect(first).to equal(second)
    end
  end

  describe "superclass_irdi" do
    it "prefers MDC_P010_1 when present" do
      expect(klass.superclass_irdi.to_s).to eq("0112/2///62683#ACC001")
    end

    context "when only MDC_P010 is populated" do
      let(:row) do
        {
          "MDC_P001_5" => "0112/2///62683#ACC002",
          "MDC_P010"   => "0112/2///62683#ACC001",
        }
      end

      it "falls back to MDC_P010" do
        expect(klass.superclass_irdi.to_s).to eq("0112/2///62683#ACC001")
      end
    end

    it "returns nil for empty/blank value" do
      row_empty = { "MDC_P001_5" => "0112/2///62683#ACC002", "MDC_P010_1" => "  " }
      k = described_class.from_row(row_empty, schema: schema, meta_class_irdi: meta)
      expect(k.superclass_irdi).to be_nil
    end
  end

  describe "is_case_of_irdis" do
    it "parses IRDI references" do
      expect(klass.is_case_of_irdis.map(&:to_s)).to eq(["0112/2///62683#ACC099"])
    end
  end

  describe "applicable_property_irdis" do
    it "parses multiple IRDIs from whitespace-separated string" do
      expect(klass.applicable_property_irdis.map(&:to_s))
        .to eq(["0112/2///62683#ACE001", "0112/2///62683#ACE002"])
    end
  end

  describe "imported_property_irdis" do
    it "parses IRDI references" do
      expect(klass.imported_property_irdis.map(&:to_s))
        .to eq(["0112/2///62683#ACE003"])
    end
  end

  describe "sub_class_selection_irdis" do
    it "parses IRDI references" do
      expect(klass.sub_class_selection_irdis.map(&:to_s))
        .to eq(["0112/2///62683#ACC050"])
    end
  end

  describe "predicates" do
    subject(:categorical) do
      described_class.from_row(
        { "MDC_P001_5" => "0112/2///62683#ACC002", "MDC_P011" => "CATEGORICAL_CLASS" },
        schema: schema, meta_class_irdi: meta,
      )
    end

    let(:item) do
      described_class.from_row(
        { "MDC_P001_5" => "0112/2///62683#ACC002", "MDC_P011" => "ITEM_CLASS" },
        schema: schema, meta_class_irdi: meta,
      )
    end

    it "classifies categorical classes" do
      expect(categorical).to be_categorical
      expect(categorical).not_to be_item
    end

    it "classifies item classes" do
      expect(item).to be_item
      expect(item).not_to be_categorical
    end
  end

  describe "parent_property_id" do
    it "returns MDC_P010_1 when the schema has that column" do
      expect(klass.parent_property_id).to eq("MDC_P010_1")
    end

    context "when only MDC_P010 is present in schema" do
      let(:schema) do
        Opencdd::Parcel::SheetSchema.from_header_rows([
          ["#PROPERTY_ID", "MDC_P001_5", "MDC_P010"],
          ["#PROPERTY_NAME.en", "Code", "Superclass"],
          ["#DATATYPE", "STRING_TYPE", "ICID_STRING"],
        ])
      end

      it "returns MDC_P010" do
        expect(klass.parent_property_id).to eq("MDC_P010")
      end
    end

    context "when neither is in schema" do
      let(:schema) { nil }

      it "defaults to MDC_P010" do
        expect(klass.parent_property_id).to eq("MDC_P010")
      end
    end
  end

  describe "tree navigation" do
    let(:parent) do
      described_class.from_row(
        { "MDC_P001_5" => "0112/2///62683#ACC001", "MDC_P011" => "ITEM_CLASS" },
        schema: schema, meta_class_irdi: meta,
      )
    end

    let(:child) do
      described_class.from_row(
        { "MDC_P001_5" => "0112/2///62683#ACC002", "MDC_P010_1" => "0112/2///62683#ACC001", "MDC_P011" => "ITEM_CLASS" },
        schema: schema, meta_class_irdi: meta,
      )
    end

    it "exposes children collection" do
      parent.add_child(child)
      expect(parent.children).to include(child)
      expect(parent.subclasses).to eq([child])
    end
  end
end
