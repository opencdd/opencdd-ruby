# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::Database, "#drop_dictionary" do
  let(:db) { Cdd::Database.new }

  def make_dictionary(parcel_id, class_codes:)
    Cdd::Database.new.tap do |d|
      class_codes.each do |code|
        d.add_entity(Cdd::Klass.new(
          irdi: Cdd::IRDI.parse("0112/2///#{parcel_id}##{code}"),
          properties: { "MDC_P001_5" => code, "MDC_P011" => "ITEM_CLASS" },
          meta_class_irdi: Cdd::IRDI.parse("MDC_C002"),
        ))
      end
      d.finalize!
    end
  end

  it "removes the workbook matching the parcel_id" do
    db.add_dictionary(Cdd::Database::Dictionary.new(parcel_id: "OCDD1"))
    expect(db.workbooks.size).to eq(1)
    db.drop_dictionary("OCDD1")
    expect(db.workbooks.size).to eq(0)
  end

  it "drops entities that came from a workbook with matching parcel_id" do
    source_db = make_dictionary("OCDD1", class_codes: %w[AAA001 AAA002])
    klass_sheet = Cdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
    code_col = klass_sheet.schema.find_by_property_id("MDC_P001_5")
    class_type_col = klass_sheet.schema.find_by_property_id("MDC_P011")
    raw_rows = source_db.entities_of_type(:class).map do |e|
      row = Array.new([code_col.index, class_type_col.index].max + 1)
      row[code_col.index] = e.code
      row[class_type_col.index] = "ITEM_CLASS"
      row
    end
    sheet = Cdd::Parcel::Sheet.new(
      name: "OCDD1_CLASS",
      metadata: klass_sheet.metadata,
      schema: klass_sheet.schema,
      raw_rows: raw_rows,
    )
    project = Cdd::Parcel::Workbook::ProjectInfo.new(
      project_id: "OCDD1", parcel_id: "OCDD1",
      multi_language: "", base_language: "en",
    )
    full_wb = Cdd::Parcel::Workbook.new(sheets: [sheet], sheetmap: [], project: project)
    merged = Cdd::Database.new
    merged.add_workbook(full_wb)
    merged.finalize!

    expect(merged.classes.size).to be > 0
    merged.drop_dictionary("OCDD1")
    expect(merged.classes.size).to eq(0)
  end

  it "raises ArgumentError when no dictionary matches" do
    expect {
      db.drop_dictionary("NOPE")
    }.to raise_error(ArgumentError, /no dictionary/)
  end

  it "preserves other dictionaries" do
    db.add_dictionary(Cdd::Database::Dictionary.new(parcel_id: "OCDD1"))
    db.add_dictionary(Cdd::Database::Dictionary.new(parcel_id: "OCDD2"))
    db.drop_dictionary("OCDD1")
    expect(db.workbooks.size).to eq(1)
    expect(db.workbooks.first.parcel_id).to eq("OCDD2")
  end

  it "is idempotent: add → drop → add ends in the same state" do
    dict = Cdd::Database::Dictionary.new(parcel_id: "OCDD1")
    db.add_dictionary(dict)
    db.drop_dictionary("OCDD1")
    db.add_dictionary(dict)
    expect(db.workbooks.size).to eq(1)
    expect(db.workbooks.first.parcel_id).to eq("OCDD1")
  end
end
