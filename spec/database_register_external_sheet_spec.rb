# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Database, "#register_external_sheet" do
  let(:db) { Opencdd::Database.new }

  def make_sheet(name = "OCDD1_CLASS")
    Opencdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1", sheet_name: name)
  end

  it "registers the sheet under an existing dictionary" do
    db.add_dictionary(Opencdd::Database::Dictionary.new(parcel_id: "OCDD1"))
    sheet = make_sheet("OCDD1_EXTRA")
    db.register_external_sheet(sheet, parcel_id: "OCDD1")
    wb = db.workbooks.first
    expect(wb.sheets.map(&:name)).to include("OCDD1_EXTRA")
    expect(wb.sheetmap.map(&:sheet_name)).to include("OCDD1_EXTRA")
  end

  it "creates a new dictionary when parcel_id is unknown" do
    sheet = make_sheet
    db.register_external_sheet(sheet, parcel_id: "OCDD2")
    expect(db.workbooks.size).to eq(1)
    expect(db.workbooks.first.parcel_id).to eq("OCDD2")
    expect(db.workbooks.first.sheets).to include(sheet)
  end

  it "rejects invalid parcel IDs" do
    sheet = make_sheet
    expect {
      db.register_external_sheet(sheet, parcel_id: "bad id")
    }.to raise_error(ArgumentError, /invalid parcel_id/)
  end

  it "returns self for chaining" do
    sheet = make_sheet
    expect(db.register_external_sheet(sheet, parcel_id: "OCDD1")).to be(db)
  end
end
