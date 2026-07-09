# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::ValueTerm do
  let(:meta) { Cdd::IRDI.parse("0112/2///62656_1#MDC_C010") }

  let(:schema) do
    Cdd::Parcel::SheetSchema.from_header_rows([
      ["#PROPERTY_ID", "MDC_P001_11", "MDC_P018_1", "MDC_P022", "MDC_P044", "MDC_P021"],
      ["#PROPERTY_NAME.en", "Code", "Value list", "Data type", "Code of value", "Definition class"],
    ])
  end

  let(:row) do
    {
      "MDC_P001_11" => "0112/2///62683#ACJ001",
      "MDC_P018_1"  => "0112/2///62683#ACI001",
      "MDC_P022"    => "STRING_TYPE",
      "MDC_P044"    => "001",
      "MDC_P021"    => "0112/2///62683#ACC001",
    }
  end

  subject(:term) do
    described_class.from_row(row, schema: schema, meta_class_irdi: meta)
  end

  its(:irdi) { should eq(Cdd::IRDI.parse("0112/2///62683#ACJ001")) }

  its(:enumeration_code) { should eq("001") }
  its(:term_code) { should eq("001") }
  its(:data_type) { should eq("STRING_TYPE") }

  it "parses the value_list_irdi from MDC_P018_1" do
    expect(term.value_list_irdi.to_s).to eq("0112/2///62683#ACI001")
  end

  it "parses the definition_class_irdi from MDC_P021" do
    expect(term.definition_class_irdi.to_s).to eq("0112/2///62683#ACC001")
  end

  context "when only the legacy VALUE_LIST_IRDI column is populated" do
    let(:row) { { "VALUE_LIST_IRDI" => "0112/2///62683#ACI001", "MDC_P001_11" => "0112/2///62683#ACJ001" } }

    it "falls back to the legacy column" do
      expect(term.value_list_irdi.to_s).to eq("0112/2///62683#ACI001")
    end
  end

  context "when no value list column is populated" do
    let(:row) { { "MDC_P001_11" => "0112/2///62683#ACJ001" } }

    it "returns nil without raising" do
      expect(term.value_list_irdi).to be_nil
    end
  end

  it "is a Cdd::ParseHelpers via Entity" do
    expect(term).to be_a(Cdd::ParseHelpers)
  end
end
