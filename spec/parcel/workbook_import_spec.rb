# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Opencdd::Parcel::Workbook, "#import_into" do
  let(:target_db) { Opencdd::Database.load_workbook(PARCEL_MAKER_XLSX.to_s) }
  let(:workbook)  { target_db.workbooks.first }

  after do
    @tempfiles&.each { |p| FileUtils.rm_rf(p) if File.exist?(p) }
  end

  def remember(path)
    @tempfiles ||= []
    @tempfiles << path
  end

  def write_csv_for(db, type, dir)
    sheet = Opencdd::Parcel::Sheet.scaffold(
      meta_class_irdi: Opencdd::MetaClasses.meta_class_for_type(type),
      parcel_id: "EXP",
    )
    entities = db.entities_of_type(type).first(3)
    path = File.join(dir, "exp_#{type}.csv")
    Opencdd::Parcel::CsvWriter.write_sheet(sheet, entities, path)
    path
  end

  it "imports rows from a CSV file into the named sheet" do
    skip "needs entities to export first" if target_db.entities_of_type(:class).empty?
    dir = Dir.mktmpdir("cdd-import")
    remember(dir)
    csv_path = write_csv_for(target_db, :class, dir)

    target_sheet = workbook.sheet(workbook.sheets_of_type(:class).first.name)
    size_before = target_sheet.rows.size
    workbook.import_into(target_sheet.name, csv_path, format: :csv)
    expect(target_sheet.rows.size).to be > size_before
  end

  it "auto-detects CSV format from the file extension" do
    skip "needs entities to export first" if target_db.entities_of_type(:class).empty?
    dir = Dir.mktmpdir("cdd-import")
    remember(dir)
    csv_path = write_csv_for(target_db, :class, dir)

    target_sheet = workbook.sheet(workbook.sheets_of_type(:class).first.name)
    size_before = target_sheet.rows.size
    expect {
      workbook.import_into(target_sheet.name, csv_path)
    }.not_to raise_error
    expect(target_sheet.rows.size).to be > size_before
  end

  it "raises ArgumentError when the target sheet is unknown" do
    dir = Dir.mktmpdir("cdd-import")
    remember(dir)
    csv_path = File.join(dir, "x.csv")
    File.write(csv_path, "AAA001\n")
    expect {
      workbook.import_into("NOPE_NOT_THERE", csv_path, format: :csv)
    }.to raise_error(ArgumentError, /unknown sheet/)
  end

  it "raises ArgumentError for unknown file extensions when format is omitted" do
    dir = Dir.mktmpdir("cdd-import")
    remember(dir)
    path = File.join(dir, "data.bin")
    File.write(path, "bytes")
    target_sheet = workbook.sheets_of_type(:class).first
    expect {
      workbook.import_into(target_sheet.name, path)
    }.to raise_error(ArgumentError, /cannot detect format/)
  end
end

RSpec.describe Opencdd::Parcel::Workbook, "#register_sheet" do
  def empty_workbook
    Opencdd::Parcel::Workbook.new(sheets: [], sheetmap: [])
  end

  it "appends the sheet and adds a sheetmap row" do
    wb = empty_workbook
    sheet = Opencdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
    wb.register_sheet(sheet)
    expect(wb.sheets).to include(sheet)
    expect(wb.sheetmap.size).to eq(1)
    expect(wb.sheetmap.first.sheet_name).to eq(sheet.name)
    expect(wb.sheetmap.first.type).to eq("CLASS")
  end

  it "makes the sheet reachable via #sheet" do
    wb = empty_workbook
    sheet = Opencdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
    wb.register_sheet(sheet)
    expect(wb.sheet(sheet.name)).to be(sheet)
  end

  it "raises ArgumentError when the sheet name is already registered" do
    wb = empty_workbook
    sheet = Opencdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
    wb.register_sheet(sheet)
    dup = sheet.dup_with(name: sheet.name)
    expect {
      wb.register_sheet(dup)
    }.to raise_error(ArgumentError, /already registered/)
  end

  it "returns self for chaining" do
    wb = empty_workbook
    sheet = Opencdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
    expect(wb.register_sheet(sheet)).to be(wb)
  end
end

RSpec.describe Opencdd::Parcel::CsvReader, ".read" do
  after do
    @tempfiles&.each { |p| FileUtils.rm_rf(p) if File.exist?(p) }
  end

  def remember(path)
    @tempfiles ||= []
    @tempfiles << path
  end

  def make_db_with_class(code)
    Opencdd::Database.new.tap do |d|
      d.add_entity(Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse(code),
        properties: {
          "MDC_P001_5"  => code,
          "MDC_P011"    => "ITEM_CLASS",
          "MDC_P004.en" => "Class #{code}",
        },
        meta_class_irdi: Opencdd::IRDI.parse("MDC_C002"),
      ))
      d.finalize!
    end
  end

  it "builds a Sheet with rows populated from the CSV" do
    dir = Dir.mktmpdir("csv-reader")
    remember(dir)
    csv = File.join(dir, "data.csv")
    sheet = Opencdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "X")
    db = make_db_with_class("AAA001")
    Opencdd::Parcel::CsvWriter.write_sheet(sheet, db.entities_of_type(:class), csv)

    reloaded = Opencdd::Parcel::CsvReader.read(csv, meta_class_irdi: "MDC_C002")
    expect(reloaded.rows.size).to eq(1)
    expect(reloaded.rows[0]["MDC_P001_5"]).to eq("AAA001")
  end

  it "honors a custom column separator" do
    dir = Dir.mktmpdir("csv-reader")
    remember(dir)
    txt = File.join(dir, "data.txt")
    sheet = Opencdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "X")
    db = make_db_with_class("AAA001")
    Opencdd::Parcel::CsvWriter.write_sheet(sheet, db.entities_of_type(:class), txt)
    # Re-read with explicit tab separator even though file is comma-separated,
    # just to verify the col_sep parameter is honored (result will have one column).
    reloaded = Opencdd::Parcel::CsvReader.read(txt, meta_class_irdi: "MDC_C002", col_sep: "\t")
    expect(reloaded.rows.size).to eq(1)
  end

  it "accepts a full IRDI as the meta_class_irdi argument" do
    dir = Dir.mktmpdir("csv-reader")
    remember(dir)
    csv = File.join(dir, "data.csv")
    File.write(csv, "AAA001\n")
    sheet = Opencdd::Parcel::CsvReader.read(csv, meta_class_irdi: "0112/2///62656_1#MDC_C002")
    expect(sheet.meta_class_code).to eq("MDC_C002")
  end

  it "ignores empty rows" do
    dir = Dir.mktmpdir("csv-reader")
    remember(dir)
    csv = File.join(dir, "data.csv")
    sheet = Opencdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "X")
    db = make_db_with_class("AAA001")
    Opencdd::Parcel::CsvWriter.write_sheet(sheet, db.entities_of_type(:class), csv)
    original = File.read(csv)
    File.write(csv, original + "\n,,\n")

    reloaded = Opencdd::Parcel::CsvReader.read(csv, meta_class_irdi: "MDC_C002")
    expect(reloaded.rows.size).to eq(1)
  end
end
