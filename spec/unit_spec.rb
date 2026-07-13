# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Unit, "extended accessors" do
  let(:meta) { Opencdd::IRDI.parse("0112/2///62656_1#MDC_C009") }

  let(:schema) do
    Opencdd::Parcel::SheetSchema.from_header_rows([
      ["#PROPERTY_ID", "MDC_P001_10", "MDC_P021", "MDC_P023", "MDC_P023_1", "MDC_P023_2"],
      ["#PROPERTY_NAME.en", "Code", "Structure", "Unit symbol", "Text representation", "SGML representation"],
      ["#DATATYPE", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE"],
    ])
  end

  let(:row) do
    {
      "MDC_P001_10" => "0112/2///62683#ACH005",
      "MDC_P021"    => "0112/2///62683#ACC005",
      "MDC_P023"    => "V",
      "MDC_P023_1"  => "V_text",
      "MDC_P023_2"  => "V_sgml",
    }
  end

  subject(:unit) do
    described_class.from_row(row, schema: schema, meta_class_irdi: meta)
  end

  its(:irdi) { should eq(Opencdd::IRDI.parse("0112/2///62683#ACH005")) }
  its(:structure) { should eq("V") }
  its(:text_representation) { should eq("V_text") }
  its(:sgml_representation) { should eq("V_sgml") }
  its(:symbol) { should eq("V_text") }

  describe "definition_class_irdi" do
    it "parses from MDC_P021" do
      expect(unit.definition_class_irdi.to_s).to eq("0112/2///62683#ACC005")
    end

    it "returns nil when MDC_P021 is absent" do
      row_empty = { "MDC_P001_10" => "0112/2///62683#ACH005" }
      u = described_class.from_row(row_empty, schema: schema, meta_class_irdi: meta)
      expect(u.definition_class_irdi).to be_nil
    end
  end
end
