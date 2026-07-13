# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Opencdd::Parcel::Writer do
  let(:source_xlsx) { PARCEL_MAKER_XLSX }

  let(:database) { Opencdd::Database.load_workbook(source_xlsx) }

  def write_to_tempfile(database, parcel_id: "OCDD1", **opts)
    dir = Dir.mktmpdir("cdd-writer")
    path = File.join(dir, "out.xlsx")
    described_class.new(database).write(path, parcel_id: parcel_id, **opts)
    path
  end

  after do
    @tempfiles&.each { |p| FileUtils.rm_rf(File.dirname(p)) if File.exist?(File.dirname(p)) }
  end

  def remember(path)
    @tempfiles ||= []
    @tempfiles << path
  end

  describe "#write with a single-class database" do
    let(:small_db) do
      Opencdd::Database.new.tap do |d|
        klass = Opencdd::Klass.new(
          irdi: Opencdd::IRDI.parse("0112/2///62656_1#AAA001"),
          properties: {
            "MDC_P001_5"      => "0112/2///62656_1#AAA001",
            "MDC_P002_1"      => "001",
            "MDC_P011"        => "ITEM_CLASS",
            "MDC_P004.en"     => "Test Class",
            "MDC_P006.en"     => "class for testing",
          },
          meta_class_irdi: Opencdd::IRDI.parse("MDC_C002"),
        )
        d.add_entity(klass)
        d.finalize!
      end
    end

    it "produces an xlsx file readable by Parcel::WorkbookReader" do
      path = write_to_tempfile(small_db)
      remember(path)
      reloaded = Opencdd::Database.load_workbook(path)
      expect(reloaded.classes.size).to eq(1)
      expect(reloaded.classes.first.preferred_name).to eq("Test Class")
    end
  end

  describe "round-trip with the ParcelMaker reference workbook" do
    it "round-trips with semantic equality" do
      path = write_to_tempfile(database, parcel_id: "IEC62683")
      remember(path)
      reloaded = Opencdd::Database.load_workbook(path)
      expect(reloaded.semantically_equal?(database)).to be(true)
    end

    it "writes a Project sheet with parcel_id" do
      path = write_to_tempfile(database, parcel_id: "IEC62683")
      remember(path)
      require "roo"
      roo = Roo::Spreadsheet.open(path)
      expect(roo.sheets).to include("Project")
      project = roo.sheet("Project")
      expect(project.row(2)).to include("IEC62683")
    end

    it "writes a sheetmap sheet listing every data sheet" do
      path = write_to_tempfile(database, parcel_id: "IEC62683")
      remember(path)
      require "roo"
      roo = Roo::Spreadsheet.open(path)
      expect(roo.sheets).to include("sheetmap")
      map = roo.sheet("sheetmap")
      rows = (1..map.last_row).map { |i| map.row(i) }
      sheet_names = rows.drop(1).map { |r| r[5] }
      expect(sheet_names).to include("IEC62683_CLASS", "IEC62683_PROPERTY")
    end

    it "emits every data sheet present in the source database" do
      path = write_to_tempfile(database, parcel_id: "IEC62683")
      remember(path)
      require "roo"
      roo = Roo::Spreadsheet.open(path)
      expected = database.entities.map(&:type).compact.uniq.map { |t| "IEC62683_" + type_label(t) }
      (roo.sheets & expected).sort == expected.sort
    end
  end

  describe "respecting sheet_types filter" do
    it "emits only the requested types when sheet_types is explicit" do
      path = write_to_tempfile(database, parcel_id: "IEC62683", sheet_types: [:class])
      remember(path)
      require "roo"
      roo = Roo::Spreadsheet.open(path)
      data_sheets = roo.sheets - ["Project", "sheetmap"]
      expect(data_sheets).to eq(["IEC62683_CLASS"])
    end
  end

  describe "writing to a StringIO" do
    it "writes the package bytes to the stream" do
      io = StringIO.new
      described_class.new(database).write(io, parcel_id: "IEC62683")
      expect(io.pos).to be > 0
      io.rewind
      expect(io.read(2)).to eq("PK")
    end
  end

  describe "hidden header rows from the source workbook" do
    it "marks hidden directive rows in the emitted xlsx" do
      source_wb = database.workbooks.first
      source_wb.hide_header_row!(:pattern)
      source_wb.hide_header_row!(:default_value)

      path = write_to_tempfile(database, parcel_id: "IEC62683")
      remember(path)

      require "zip"
      hidden_total = 0
      Zip::File.open(path) do |zip|
        zip.each do |entry|
          next unless entry.name =~ %r{xl/worksheets/sheet.*\.xml\z}
          xml = zip.read(entry)
          hidden_total += xml.scan(/<row[^>]*hidden="1"[^>]*>/).size
        end
      end
      expect(hidden_total).to be > 0
    end

    it "emits no hidden rows when no header is hidden" do
      path = write_to_tempfile(database, parcel_id: "IEC62683")
      remember(path)
      require "zip"
      any_hidden = false
      Zip::File.open(path) do |zip|
        zip.each do |entry|
          next unless entry.name =~ %r{xl/worksheets/sheet.*\.xml\z}
          xml = zip.read(entry)
          any_hidden = true if xml.include?('hidden="1"')
        end
      end
      expect(any_hidden).to be(false)
    end
  end

  describe "#write_sheet for a single scaffolded sheet" do
    it "emits only that sheet's rows" do
      sheet = Opencdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
      klass = Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse("AAA001"),
        properties: {
          "MDC_P001_5"  => "AAA001",
          "MDC_P011"    => "ITEM_CLASS",
          "MDC_P004.en" => "Solo Sheet",
        },
        meta_class_irdi: Opencdd::IRDI.parse("MDC_C002"),
      )
      path = File.join(Dir.mktmpdir("cdd-writer"), "single.xlsx")
      remember(path)
      described_class.new(database).write_sheet(sheet, [klass], path)
      require "roo"
      roo = Roo::Spreadsheet.open(path)
      expect(roo.sheets).to eq(["OCDD1_CLASS"])
      data_row = roo.sheet("OCDD1_CLASS").row(roo.sheet("OCDD1_CLASS").last_row)
      expect(data_row).to include("AAA001")
    end
  end

  def type_label(type)
    {
      class:        "CLASS",
      property:     "PROPERTY",
      value_list:   "ENUM",
      value_term:   "TERMINOLOGY",
      unit:         "UoM",
      relation:     "RELATION",
      view_control: "VIEWCONTROL",
    }.fetch(type, type.to_s.upcase)
  end
end
