# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Parcel::Sheet, "#dup_with" do
  def make_class_sheet(rows:)
    header = [
      ["#CLASS_ID:=MDC_C002"],
      ["#SOURCE_LANGUAGE:=en"],
      ["#PROPERTY_ID", "MDC_P001_5", "MDC_P010"],
      ["#PROPERTY_NAME.en", "Code", "Superclass"],
      ["#DATATYPE", "STRING_TYPE", "ICID_STRING"],
      ["#REQUIREMENT", "KEY", "OPT"],
    ]
    data = rows.map { |code, sup| [nil, code, sup] }
    Opencdd::Parcel::Sheet.from_rows(header + data, name: "ORIG")
  end

  it "creates a sheet with the new name and same data" do
    original = make_class_sheet(rows: [["AAA001", nil], ["AAA002", "AAA001"]])
    copy = original.dup_with(name: "COPY")
    expect(copy.name).to eq("COPY")
    expect(copy.rows.size).to eq(2)
    expect(copy.rows[0]["MDC_P001_5"]).to eq("AAA001")
    expect(copy.rows[1]["MDC_P010"]).to eq("AAA001")
  end

  it "preserves metadata and schema" do
    original = make_class_sheet(rows: [["AAA001", nil]])
    copy = original.dup_with(name: "COPY")
    expect(copy.meta_class_irdi).to eq(original.meta_class_irdi)
    expect(copy.schema.size).to eq(original.schema.size)
    expect(copy.schema.columns.map(&:property_id)).to eq(original.schema.columns.map(&:property_id))
  end

  it "decouples mutations: editing the copy does not affect the original" do
    original = make_class_sheet(rows: [["AAA001", nil]])
    copy = original.dup_with(name: "COPY")
    copy.merge_rows_from(make_class_sheet(rows: [["AAA099", nil]]))
    expect(original.rows.size).to eq(1)
    expect(copy.rows.size).to eq(2)
  end

  it "returns a Sheet instance" do
    original = make_class_sheet(rows: [["AAA001", nil]])
    expect(original.dup_with(name: "COPY")).to be_a(Opencdd::Parcel::Sheet)
  end
end
