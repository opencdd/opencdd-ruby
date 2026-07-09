# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::ValueList, "extended accessors" do
  let(:meta) { Cdd::IRDI.parse("0112/2///62656_1#MDC_C005") }

  let(:schema) do
    Cdd::Parcel::SheetSchema.from_header_rows([
      ["#PROPERTY_ID", "MDC_P001_12", "MDC_P043", "MDC_P044", "MDC_P045", "MDC_P046"],
      ["#PROPERTY_NAME.en", "Code", "Terms", "Codes", "Selection count", "List type"],
      ["#DATATYPE", "STRING_TYPE", "ICID_STRING", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE"],
    ])
  end

  describe "code_list" do
    it "splits comma-separated codes" do
      row = {
        "MDC_P001_12" => "0112/2///62683#ACI001",
        "MDC_P044"    => "001,002,003",
      }
      vl = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(vl.code_list).to eq(["001", "002", "003"])
    end

    it "strips parens and whitespace" do
      row = {
        "MDC_P001_12" => "0112/2///62683#ACI001",
        "MDC_P044"    => "(001, 002)",
      }
      vl = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(vl.code_list).to eq(["001", "002"])
    end

    it "returns [] for empty input" do
      row = { "MDC_P001_12" => "0112/2///62683#ACI001" }
      vl = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(vl.code_list).to eq([])
    end
  end

  describe "selection_count" do
    it "parses a comma-separated pair of integers" do
      row = {
        "MDC_P001_12" => "0112/2///62683#ACI001",
        "MDC_P045"    => "(1, 5)",
      }
      vl = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(vl.selection_count).to eq([1, 5])
    end

    it "returns nil for blank input" do
      row = { "MDC_P001_12" => "0112/2///62683#ACI001" }
      vl = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(vl.selection_count).to be_nil
    end

    it "returns nil when no integer can be parsed" do
      row = {
        "MDC_P001_12" => "0112/2///62683#ACI001",
        "MDC_P045"    => "(abc)",
      }
      vl = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(vl.selection_count).to be_nil
    end
  end

  describe "list_type aliases" do
    it "maps EXTENSIBLE to :extensible" do
      row = {
        "MDC_P001_12" => "0112/2///62683#ACI001",
        "MDC_P046"    => "EXTENSIBLE",
      }
      vl = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(vl.list_type).to eq(:extensible)
    end

    it "maps CLOSED to :closed" do
      row = {
        "MDC_P001_12" => "0112/2///62683#ACI001",
        "MDC_P046"    => "CLOSED",
      }
      vl = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(vl.list_type).to eq(:closed)
    end

    it "maps OPEN to :open" do
      row = {
        "MDC_P001_12" => "0112/2///62683#ACI001",
        "MDC_P046"    => "OPEN",
      }
      vl = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(vl.list_type).to eq(:open)
    end

    it "returns the raw value when no alias matches" do
      row = {
        "MDC_P001_12" => "0112/2///62683#ACI001",
        "MDC_P046"    => "UNKNOWN",
      }
      vl = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(vl.list_type).to eq("UNKNOWN")
    end
  end

  describe "terms iteration" do
    it "yields resolved terms from a database" do
      db = Cdd::Database.new
      meta_term = Cdd::IRDI.parse("0112/2///62656_1#MDC_C010")
      term1 = Cdd::ValueTerm.new(irdi: Cdd::IRDI.parse("0112/2///62683#ACJ001"), properties: {}, meta_class_irdi: meta_term)
      term2 = Cdd::ValueTerm.new(irdi: Cdd::IRDI.parse("0112/2///62683#ACJ002"), properties: {}, meta_class_irdi: meta_term)
      db.add_entity(term1)
      db.add_entity(term2)

      vl = described_class.from_row(
        {
          "MDC_P001_12" => "0112/2///62683#ACI001",
          "MDC_P043"    => "0112/2///62683#ACJ001 0112/2///62683#ACJ002",
        },
        schema: schema, meta_class_irdi: meta,
      )

      collected = []
      vl.terms(db) { |t| collected << t }
      expect(collected).to eq([term1, term2])
    end

    it "returns an enumerator when no block is given" do
      vl = described_class.from_row(
        { "MDC_P001_12" => "0112/2///62683#ACI001", "MDC_P043" => "0112/2///62683#ACJ001" },
        schema: schema, meta_class_irdi: meta,
      )
      expect(vl.terms).to be_an(Enumerator)
    end
  end
end
