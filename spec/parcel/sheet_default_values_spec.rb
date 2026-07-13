# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Parcel::Sheet, "#apply_default_values!" do
  def make_sheet(default_value:, rows:)
    header = [
      ["#CLASS_ID:=MDC_C002"],
      ["#SOURCE_LANGUAGE:=en"],
      ["#PROPERTY_ID", "MDC_P001_5", "MDC_P010"],
      ["#PROPERTY_NAME.en", "Code", "Superclass"],
      ["#DATATYPE", "STRING_TYPE", "ICID_STRING"],
      ["#DEFAULT_VALUE", nil, default_value],
      ["#REQUIREMENT", "KEY", "OPT"],
    ]
    data = rows.map { |code, val| [nil, code, val] }
    Opencdd::Parcel::Sheet.from_rows(header + data, name: "TEST")
  end

  it "fills empty cells with the column's default value" do
    sheet = make_sheet(default_value: "0112/2///62683#ACC001", rows: [
      ["AAA001", nil],
      ["AAA002", "custom"],
    ])
    sheet.apply_default_values!(property_id: "MDC_P010")
    expect(sheet.rows[0]["MDC_P010"]).to eq("0112/2///62683#ACC001")
    expect(sheet.rows[1]["MDC_P010"]).to eq("custom")
  end

  it "is a no-op for columns without a default" do
    sheet = make_sheet(default_value: nil, rows: [["AAA001", nil]])
    sheet.apply_default_values!(property_id: "MDC_P010")
    expect(sheet.rows[0]).not_to have_key("MDC_P010")
  end

  it "leaves other columns untouched" do
    sheet = make_sheet(default_value: "0112/2///62683#ACC001", rows: [["AAA001", nil]])
    sheet.apply_default_values!(property_id: "MDC_P010")
    expect(sheet.rows[0]["MDC_P001_5"]).to eq("AAA001")
  end

  it "returns self for chaining" do
    sheet = make_sheet(default_value: "0112/2///62683#ACC001", rows: [["AAA001", nil]])
    expect(sheet.apply_default_values!(property_id: "MDC_P010")).to be(sheet)
  end

  it "overwrites blank-string values when filling" do
    sheet = make_sheet(default_value: "0112/2///62683#ACC001", rows: [["AAA001", ""]])
    sheet.apply_default_values!(property_id: "MDC_P010")
    expect(sheet.rows[0]["MDC_P010"]).to eq("0112/2///62683#ACC001")
  end
end

RSpec.describe Opencdd::Parcel::Sheet, "#apply_all_default_values!" do
  def make_sheet(rows:)
    header = [
      ["#CLASS_ID:=MDC_C002"],
      ["#SOURCE_LANGUAGE:=en"],
      ["#PROPERTY_ID", "MDC_P001_5", "MDC_P010"],
      ["#PROPERTY_NAME.en", "Code", "Superclass"],
      ["#DATATYPE", "STRING_TYPE", "ICID_STRING"],
      ["#DEFAULT_VALUE", nil, "0112/2///62683#ACC001"],
      ["#REQUIREMENT", "KEY", "OPT"],
    ]
    data = rows.map { |code, sup| [nil, code, sup] }
    Opencdd::Parcel::Sheet.from_rows(header + data, name: "TEST")
  end

  it "fills every column that has a default" do
    sheet = make_sheet(rows: [["AAA001", nil]])
    sheet.apply_all_default_values!
    expect(sheet.rows[0]["MDC_P010"]).to eq("0112/2///62683#ACC001")
  end

  it "preserves pre-existing values across all columns" do
    sheet = make_sheet(rows: [["AAA001", "kept"]])
    sheet.apply_all_default_values!
    expect(sheet.rows[0]["MDC_P010"]).to eq("kept")
  end

  it "is a no-op when no column has a default" do
    header = [
      ["#CLASS_ID:=MDC_C002"],
      ["#SOURCE_LANGUAGE:=en"],
      ["#PROPERTY_ID", "MDC_P001_5"],
      ["#PROPERTY_NAME.en", "Code"],
      ["#DATATYPE", "STRING_TYPE"],
      ["#REQUIREMENT", "KEY"],
    ]
    data = [[nil, "AAA001"]]
    sheet = Opencdd::Parcel::Sheet.from_rows(header + data, name: "TEST")
    expect { sheet.apply_all_default_values! }.not_to raise_error
  end
end
