# frozen_string: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "csv"

RSpec.describe Cdd::Parcel::CsvWriter do
  let(:database) { Cdd::Database.load_workbook(PARCEL_MAKER_XLSX) }

  def write_csv_to_tempfile(database, parcel_id: "IEC62683", **opts)
    dir = Dir.mktmpdir("cdd-csv")
    paths = described_class.write_workbook(database, dir, parcel_id: parcel_id, **opts)
    [dir, paths]
  end

  after do
    @tempdirs&.each { |d| FileUtils.rm_rf(d) if File.directory?(d) }
  end

  def remember(dir)
    @tempdirs ||= []
    @tempdirs << dir
  end

  describe ".write_sheet with a scaffolded sheet" do
    let(:small_db) do
      Cdd::Database.new.tap do |d|
        klass = Cdd::Klass.new(
          irdi: Cdd::IRDI.parse("0112/2///62656_1#AAA001"),
          properties: {
            "MDC_P001_5"  => "0112/2///62656_1#AAA001",
            "MDC_P002_1"  => "001",
            "MDC_P011"    => "ITEM_CLASS",
            "MDC_P004.en" => "Test Class",
          },
          meta_class_irdi: Cdd::IRDI.parse("MDC_C002"),
        )
        d.add_entity(klass)
        d.finalize!
      end
    end

    it "writes data rows only (no header or metadata rows)" do
      sheet = Cdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
      io = StringIO.new
      described_class.write_sheet(sheet, small_db.classes, io)
      io.rewind
      content = io.read
      lines = content.lines
      expect(lines.none? { |l| l.start_with?("#") }).to be(true)
      expect(content).to include("0112/2///62656_1#AAA001")
      expect(content).to include("Test Class")
    end

    it "includes multilingual preferred_name value" do
      sheet = Cdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
      io = StringIO.new
      described_class.write_sheet(sheet, small_db.classes, io)
      io.rewind
      row = CSV.parse(io.read).first
      expect(row).to include("Test Class")
    end
  end

  describe ".write_workbook with ParcelMaker database" do
    it "produces one CSV file per sheet type" do
      dir, paths = write_csv_to_tempfile(database)
      remember(dir)
      expect(paths.length).to be > 0
      filenames = paths.map { |p| File.basename(p) }
      expect(filenames).to include("IEC62683_CLASS.csv", "IEC62683_PROPERTY.csv")
    end

    it "writes CSV data rows readable by Ruby CSV" do
      dir, paths = write_csv_to_tempfile(database)
      remember(dir)
      class_csv = paths.find { |p| p.end_with?("_CLASS.csv") }
      rows = CSV.read(class_csv)
      expect(rows.length).to be > 0
      expect(rows.first.length).to be > 1
    end

    it "quotes cells containing commas (set-of-refs)" do
      dir, paths = write_csv_to_tempfile(database)
      remember(dir)
      class_csv = paths.find { |p| p.end_with?("_CLASS.csv") }
      content = File.read(class_csv)
      expect(content).to match(/"/)
    end
  end

  describe "encoding" do
    it "writes UTF-8 by default" do
      dir, paths = write_csv_to_tempfile(database)
      remember(dir)
      content = File.read(paths.first, encoding: "UTF-8")
      expect(content.encoding.name).to eq("UTF-8")
    end

    it "writes UTF-8 BOM when write_bom is true" do
      dir, paths = write_csv_to_tempfile(database, write_bom: true)
      remember(dir)
      bom = File.binread(paths.first, 3)
      expect(bom.bytes).to eq([0xEF, 0xBB, 0xBF])
    end

    it "does not write BOM by default" do
      dir, paths = write_csv_to_tempfile(database)
      remember(dir)
      bom = File.binread(paths.first, 3)
      expect(bom).not_to eq("\xEF\xBB\xBF")
    end
  end

  describe "writing to a StringIO" do
    it "writes CSV rows to the stream" do
      sheet = Cdd::Parcel::Sheet.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
      klass = Cdd::Klass.new(
        irdi: Cdd::IRDI.parse("AAA001"),
        properties: { "MDC_P004.en" => "Solo" },
        meta_class_irdi: Cdd::IRDI.parse("MDC_C002"),
      )
      io = StringIO.new
      described_class.write_sheet(sheet, [klass], io)
      expect(io.pos).to be > 0
    end
  end
end
