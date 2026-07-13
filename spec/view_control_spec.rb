# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::ViewControl do
  let(:meta) { Opencdd::IRDI.parse("0112/2///62656_1#EXT_C001") }

  let(:schema) do
    Opencdd::Parcel::SheetSchema.from_header_rows([
      ["#PROPERTY_ID", "EXT_P001", "EXT_P002", "EXT_P003", "MDC_P066", "MDC_P067"],
      ["#PROPERTY_NAME.en", "Code", "Controlled classes", "Shown properties", "DOI", "Time stamp"],
      ["#DATATYPE", "STRING_TYPE", "ICID_STRING", "ICID_STRING", "STRING_TYPE", "DATE_TIME_TYPE"],
    ])
  end

  let(:row) do
    {
      "EXT_P001" => "0112/2///62683#ACV001",
      "EXT_P002" => "0112/2///62683#ACC001 0112/2///62683#ACC002",
      "EXT_P003" => "0112/2///62683#ACE001",
      "MDC_P066" => "doi:10.1234/example",
      "MDC_P067" => "2026-06-23T12:00:00Z",
    }
  end

  subject(:view_control) do
    described_class.from_row(row, schema: schema, meta_class_irdi: meta)
  end

  its(:irdi) { should eq(Opencdd::IRDI.parse("0112/2///62683#ACV001")) }
  its(:data_object_identifier) { should eq("doi:10.1234/example") }
  its(:time_stamp) { should eq("2026-06-23T12:00:00Z") }

  it "parses controlled class IRDIs from whitespace-separated string" do
    expect(view_control.controlled_class_irdis.map(&:to_s))
      .to eq(["0112/2///62683#ACC001", "0112/2///62683#ACC002"])
  end

  it "parses shown property IRDIs" do
    expect(view_control.shown_property_irdis.map(&:to_s))
      .to eq(["0112/2///62683#ACE001"])
  end

  it "inherits ParseHelpers through Entity" do
    expect(view_control).to be_a(Opencdd::ParseHelpers)
  end
end
