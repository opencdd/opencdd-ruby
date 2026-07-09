# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::Property, "extended accessors" do
  let(:meta) { Cdd::IRDI.parse("0112/2///62656_1#MDC_C003") }

  let(:schema) do
    Cdd::Parcel::SheetSchema.from_header_rows([
      ["#PROPERTY_ID", "MDC_P001_6", "MDC_P020", "MDC_P021", "MDC_P022", "MDC_P024", "MDC_P025_1", "MDC_P027_1", "MDC_P028", "MDC_P041", "MDC_P042", "MDC_P068"],
      ["#PROPERTY_NAME.en", "Code", "PDE type", "Definition class", "Data type", "Value format", "Symbol", "Formula", "Condition", "Unit", "Alt units", "Constraint"],
      ["#DATATYPE", "STRING_TYPE", "STRING_TYPE", "ICID_STRING", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE", "ICID_STRING", "ICID_STRING", "STRING_TYPE"],
    ])
  end

  describe "data_type parsing" do
    it "parses known data types into symbols via DATA_TYPE_ALIASES" do
      row = { "MDC_P001_6" => "0112/2///62683#ACE001", "MDC_P022" => "REAL_MEASURE_TYPE" }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.data_type).to eq(:real_measure)
      expect(p.parsed_data_type).to be_a(Cdd::DataType::RealMeasureType)
    end

    it "returns the raw value for unknown data types" do
      row = { "MDC_P001_6" => "0112/2///62683#ACE001", "MDC_P022" => "UNKNOWN_TYPE" }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.data_type).to eq("UNKNOWN_TYPE")
    end

    it "recognizes CLASS_REFERENCE as a class reference" do
      row = { "MDC_P001_6" => "0112/2///62683#ACE001", "MDC_P022" => "CLASS_REFERENCE(0112/2///62683#ACC001)" }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.class_reference?).to be(true)
      expect(p.parsed_data_type).to be_a(Cdd::DataType::ClassReference)
    end

    it "recognizes ENUM_STRING_TYPE as an enum reference" do
      row = { "MDC_P001_6" => "0112/2///62683#ACE001", "MDC_P022" => "ENUM_STRING_TYPE(0112/2///62683#ACI001)" }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.enum?).to be(true)
      expect(p.parsed_data_type).to be_a(Cdd::DataType::EnumStringType)
    end
  end

  describe "definition_class_irdi" do
    it "parses the definition class IRDI from MDC_P021" do
      row = {
        "MDC_P001_6" => "0112/2///62683#ACE001",
        "MDC_P021"   => "0112/2///62683#ACC001",
      }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.definition_class_irdi.to_s).to eq("0112/2///62683#ACC001")
    end

    it "returns nil when MDC_P021 is absent" do
      row = { "MDC_P001_6" => "0112/2///62683#ACE001" }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.definition_class_irdi).to be_nil
    end
  end

  describe "unit references" do
    it "parses unit_irdi from MDC_P041" do
      row = {
        "MDC_P001_6" => "0112/2///62683#ACE001",
        "MDC_P041"   => "0112/2///62683#ACH005",
      }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.unit_irdi.to_s).to eq("0112/2///62683#ACH005")
    end

    it "parses alternative_unit_irdis from MDC_P042" do
      row = {
        "MDC_P001_6" => "0112/2///62683#ACE001",
        "MDC_P042"   => "{0112/2///62683#ACH005,0112/2///62683#ACH006}",
      }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.alternative_unit_irdis.map(&:to_s))
        .to eq(["0112/2///62683#ACH005", "0112/2///62683#ACH006"])
    end
  end

  describe "display and formula" do
    it "reads symbol_in_text from MDC_P025_1" do
      row = {
        "MDC_P001_6" => "0112/2///62683#ACE001",
        "MDC_P025_1" => "U",
      }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.symbol_in_text).to eq("U")
    end

    it "reads formula from MDC_P027_1, falling back to MDC_P027_2" do
      row = {
        "MDC_P001_6" => "0112/2///62683#ACE001",
        "MDC_P027_1" => "a + b",
        "MDC_P027_2" => "a + b (MathML)",
      }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.formula).to eq("a + b")

      row_only_sgml = { "MDC_P001_6" => "0112/2///62683#ACE001", "MDC_P027_2" => "a + b (MathML)" }
      p2 = described_class.from_row(row_only_sgml, schema: schema, meta_class_irdi: meta)
      expect(p2.formula).to eq("a + b (MathML)")
    end
  end

  describe "constraints and conditions" do
    it "exposes raw constraint and parsed condition" do
      row = {
        "MDC_P001_6" => "0112/2///62683#ACE001",
        "MDC_P068"   => "max_length=20",
        "MDC_P028"   => 'class_type == "CATEGORICAL_CLASS"',
      }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.constraint).to eq("max_length=20")
      expect(p.condition_raw).to eq('class_type == "CATEGORICAL_CLASS"')
      expect(p.condition).to be_a(Cdd::Condition)
      expect(p.condition.satisfied_by?("class_type" => "CATEGORICAL_CLASS")).to be(true)
    end

    it "returns nil when MDC_P028 is empty" do
      row = { "MDC_P001_6" => "0112/2///62683#ACE001" }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.condition).to be_nil
    end
  end

  describe "property_data_element_type" do
    it "parses DEPENDENT_P_DET from MDC_P020" do
      row = {
        "MDC_P001_6" => "0112/2///62683#ACE001",
        "MDC_P020"   => "DEPENDENT_P_DET",
      }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.property_data_element_type.to_s).to eq("DEPENDENT_P_DET")
      expect(p.data_element_type.to_s).to eq("DEPENDENT_P_DET")
      expect(p.conditional?).to be(true)
    end

    it "parses CONDITION_DET as conditional" do
      row = {
        "MDC_P001_6" => "0112/2///62683#ACE001",
        "MDC_P020"   => "CONDITION_DET",
      }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.property_data_element_type.condition?).to be(true)
      expect(p.conditional?).to be(true)
    end

    it "is not conditional for a NON_DEPENDENT_P_DET property" do
      row = {
        "MDC_P001_6" => "0112/2///62683#ACE001",
        "MDC_P020"   => "NON_DEPENDENT_P_DET",
      }
      p = described_class.from_row(row, schema: schema, meta_class_irdi: meta)
      expect(p.property_data_element_type.non_dependent?).to be(true)
      expect(p.conditional?).to be(false)
    end
  end

  describe "attaches_to delegation" do
    it "raises NotImplementedError directing callers to Database" do
      p = described_class.from_row(
        { "MDC_P001_6" => "0112/2///62683#ACE001" },
        schema: schema, meta_class_irdi: meta,
      )
      expect { p.attaches_to }.to raise_error(NotImplementedError, /Database/)
      expect { p.applies_to }.to raise_error(NotImplementedError, /Database/)
    end
  end
end
