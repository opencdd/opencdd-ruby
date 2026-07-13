# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Property do
  let(:meta) { Opencdd::IRDI.parse("0112/2///62656_1#MDC_C003") }

  let(:schema) do
    Opencdd::Parcel::SheetSchema.from_header_rows([
      ["#PROPERTY_ID", "MDC_P001_6", "MDC_P022", "MDC_P024", "MDC_P041"],
      ["#PROPERTY_NAME.en", "Code", "Data type", "Value format", "Code for unit"],
      ["#DATATYPE", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE", "ICID_STRING"],
    ])
  end

  let(:row) do
    {
      "MDC_P001_6" => "0112/2///62683#ACE001",
      "MDC_P022"   => "REAL_MEASURE_TYPE",
      "MDC_P024"   => "NR3..12.3",
      "MDC_P041"   => "0112/2///62683#ACH990",
    }
  end

  subject(:property) do
    described_class.from_row(row, schema: schema, meta_class_irdi: meta)
  end

  its(:irdi) { should eq(Opencdd::IRDI.parse("0112/2///62683#ACE001")) }
  its(:data_type) { should eq(:real_measure) }
  its(:value_format) { should eq("NR3..12.3") }

  it "exposes unit_irdi as an IRDI object" do
    expect(property.unit_irdi).to eq(Opencdd::IRDI.parse("0112/2///62683#ACH990"))
  end
end

RSpec.describe Opencdd::ValueList do
  let(:meta) { Opencdd::IRDI.parse("0112/2///62656_1#MDC_C005") }

  let(:schema) do
    Opencdd::Parcel::SheetSchema.from_header_rows([
      ["#PROPERTY_ID", "MDC_P001_12", "MDC_P043", "MDC_P046"],
      ["#PROPERTY_NAME.en", "Code", "Enumerated list of terms", "Type of list"],
    ])
  end

  let(:row) do
    {
      "MDC_P001_12" => "0112/2///62683#ACI001",
      "MDC_P043"    => "0112/2///62683#ACJ001 0112/2///62683#ACJ002",
      "MDC_P046"    => "EXTENSIBLE",
    }
  end

  subject(:value_list) do
    described_class.from_row(row, schema: schema, meta_class_irdi: meta)
  end

  its(:list_type) { should eq(:extensible) }

  it "parses term IRDIs from whitespace/comma-separated string" do
    expect(value_list.term_irdis.map(&:to_s))
      .to eq(["0112/2///62683#ACJ001", "0112/2///62683#ACJ002"])
  end
end

RSpec.describe Opencdd::Unit do
  let(:meta) { Opencdd::IRDI.parse("0112/2///62656_1#MDC_C009") }

  let(:schema) do
    Opencdd::Parcel::SheetSchema.from_header_rows([
      ["#PROPERTY_ID", "MDC_P001_10", "MDC_P023_1"],
      ["#PROPERTY_NAME.en", "Code", "Unit in text"],
    ])
  end

  let(:row) do
    {
      "MDC_P001_10" => "0112/2///62683#ACH005",
      "MDC_P023_1"  => "V",
    }
  end

  subject(:unit) { described_class.from_row(row, schema: schema, meta_class_irdi: meta) }

  its(:text_representation) { should eq("V") }
  its(:symbol) { should eq("V") }
end

RSpec.describe Opencdd::Relation do
  let(:meta) { Opencdd::IRDI.parse("0112/2///62656_1#MDC_C011") }

  let(:schema) do
    Opencdd::Parcel::SheetSchema.from_header_rows([
      ["#PROPERTY_ID", "MDC_P001_13", "MDC_P200", "MDC_P201", "MDC_P203"],
      ["#PROPERTY_NAME.en", "Code", "Relation type", "Domain", "Codomain"],
    ])
  end

  let(:row) do
    {
      "MDC_P001_13" => "0112/2///62683#ACK001",
      "MDC_P200"    => "PREDICATION",
      "MDC_P201"    => "0112/2///62683#ACE001",
      "MDC_P203"    => "0112/2///62683#ACI001",
    }
  end

  subject(:relation) do
    described_class.from_row(row, schema: schema, meta_class_irdi: meta)
  end

  its(:relation_type_symbol) { should eq(:predication) }
  it { expect(relation.relation_type).to be_a(Opencdd::RelationType) }
  it { expect(relation).to be_predication }

  it "parses domain_irdis and codomain_irdi" do
    expect(relation.domain_irdis.map(&:to_s)).to eq(["0112/2///62683#ACE001"])
    expect(relation.codomain_irdi.to_s).to eq("0112/2///62683#ACI001")
  end
end
