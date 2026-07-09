# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::Parcel::Sheet, "#merge_rows_from" do
  def make_class_sheet(rows:, default_value: nil)
    header = [
      ["#CLASS_ID:=MDC_C002"],
      ["#SOURCE_LANGUAGE:=en"],
      ["#PROPERTY_ID", "MDC_P001_5", "MDC_P010"],
      ["#PROPERTY_NAME.en", "Code", "Superclass"],
      ["#DATATYPE", "STRING_TYPE", "ICID_STRING"],
      ["#REQUIREMENT", "KEY", "OPT"],
    ]
    header << ["#DEFAULT_VALUE", nil, default_value] if default_value
    data = rows.map { |code, sup| [nil, code, sup] }
    Cdd::Parcel::Sheet.from_rows(header + data, name: "TEST")
  end

  it "appends rows from a same-meta-class source sheet" do
    target = make_class_sheet(rows: [["AAA001", nil]])
    source = make_class_sheet(rows: [["AAA002", "AAA001"], ["AAA003", "AAA001"]])
    target.merge_rows_from(source)
    expect(target.rows.size).to eq(3)
    expect(target.rows[1]["MDC_P001_5"]).to eq("AAA002")
    expect(target.rows[2]["MDC_P001_5"]).to eq("AAA003")
  end

  it "raises ArgumentError when meta-classes differ" do
    target = make_class_sheet(rows: [["AAA001", nil]])
    other_header = [
      ["#CLASS_ID:=MDC_C003"],
      ["#SOURCE_LANGUAGE:=en"],
      ["#PROPERTY_ID", "MDC_P001_5"],
      ["#PROPERTY_NAME.en", "Code"],
      ["#DATATYPE", "STRING_TYPE"],
      ["#REQUIREMENT", "KEY"],
    ]
    other = Cdd::Parcel::Sheet.from_rows(other_header + [[nil, "PPP001"]], name: "PROP")
    expect {
      target.merge_rows_from(other)
    }.to raise_error(ArgumentError, /meta-class mismatch/)
  end

  it "preserves target row indices" do
    target = make_class_sheet(rows: [["AAA001", nil]])
    source = make_class_sheet(rows: [["AAA002", "AAA001"]])
    target.merge_rows_from(source)
    expect(target.rows[0]["__row_index__"]).to eq(0)
    expect(target.rows[1]["__row_index__"]).to eq(1)
  end

  it "does not mutate the source sheet" do
    target = make_class_sheet(rows: [["AAA001", nil]])
    source = make_class_sheet(rows: [["AAA002", "AAA001"]])
    source_size_before = source.rows.size
    source_first_index_before = source.rows.first["__row_index__"]
    target.merge_rows_from(source)
    expect(source.rows.size).to eq(source_size_before)
    expect(source.rows.first["__row_index__"]).to eq(source_first_index_before)
  end

  it "returns self for chaining" do
    target = make_class_sheet(rows: [["AAA001", nil]])
    source = make_class_sheet(rows: [["AAA002", "AAA001"]])
    expect(target.merge_rows_from(source)).to be(target)
  end
end
