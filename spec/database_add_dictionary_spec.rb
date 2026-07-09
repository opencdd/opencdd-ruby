# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::Database, "#add_dictionary" do
  let(:db) { Cdd::Database.new }

  it "creates a workbook with Class and Property sheets by default" do
    dict = Cdd::Database::Dictionary.new(
      parcel_id: "OCDD1",
      source_language: "en",
    )
    wb = db.add_dictionary(dict)
    expect(wb).to be_a(Cdd::Parcel::Workbook)
    expect(wb.sheets.size).to eq(2)
    sheet_codes = wb.sheets.map(&:meta_class_code)
    expect(sheet_codes).to contain_exactly("MDC_C002", "MDC_C003")
  end

  it "forces Class and Property even when not requested" do
    dict = Cdd::Database::Dictionary.new(
      parcel_id: "OCDD1",
      meta_class_irdis: ["MDC_C009"],
    )
    wb = db.add_dictionary(dict)
    sheet_codes = wb.sheets.map(&:meta_class_code)
    expect(sheet_codes).to contain_exactly("MDC_C002", "MDC_C003", "MDC_C009")
  end

  it "registers the workbook in the database" do
    db.add_dictionary(Cdd::Database::Dictionary.new(parcel_id: "OCDD1"))
    expect(db.workbooks.size).to eq(1)
    expect(db.workbooks.first.parcel_id).to eq("OCDD1")
  end

  it "populates sheetmap with pcls_LOCAL and per-sheet rows" do
    wb = db.add_dictionary(Cdd::Database::Dictionary.new(parcel_id: "OCDD1"))
    expect(wb.sheetmap.size).to eq(3)
    expect(wb.sheetmap.first.sheet_name).to eq("pcls_LOCAL")
    expect(wb.sheetmap.first.type).to eq("PARCEL_LIST")
  end

  it "records the project info on the workbook" do
    wb = db.add_dictionary(Cdd::Database::Dictionary.new(
      parcel_id: "OCDD1",
      source_language: "fr",
      translation_languages: %w[de ja],
    ))
    expect(wb.parcel_id).to eq("OCDD1")
    expect(wb.base_language).to eq("fr")
    expect(wb.project.multi_language).to eq("de,ja")
  end

  it "rejects invalid parcel IDs" do
    expect {
      db.add_dictionary(Cdd::Database::Dictionary.new(parcel_id: "bad id"))
    }.to raise_error(ArgumentError, /invalid parcel_id/)
    expect {
      db.add_dictionary(Cdd::Database::Dictionary.new(parcel_id: "lower"))
    }.to raise_error(ArgumentError, /invalid parcel_id/)
  end

  it "lists the new dictionary in #dictionaries" do
    db.add_dictionary(Cdd::Database::Dictionary.new(parcel_id: "OCDD1"))
    expect(db.dictionaries.size).to eq(1)
    expect(db.dictionaries.first.parcel_id).to eq("OCDD1")
    expect(db.dictionaries.first.meta_class_irdis.map(&:to_s)).to include("MDC_C002", "MDC_C003")
  end
end
