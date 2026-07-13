# frozen_string_literal: true

module Opencdd
  module Parcel
    # Reads the legacy "flat directory" Parcel layout: one directory
    # containing 1-6 +export_(CLASS|PROPERTY|RELATION|UNIT|VALUELIST|
    # VALUETERMS)_*.xls+ files at the top level. This is the format
    # cdd.iec.ch's "EXCEL format" export produces when downloaded
    # per-type without sharding by class.
    #
    # For per-class sharded subdirs see +Opencdd::Parcel::ShardedDirReader+.
    # For single .xlsx workbooks see +Opencdd::Parcel::WorkbookReader+.
    class FlatDirReader
      # FILE_PATTERN moved to Opencdd::Parcel::LayoutDetector (SSOT).
      # Kept here as an alias for back-compat with callers that
      # reference FlatDirReader::FILE_PATTERN directly.
      FILE_PATTERN = Opencdd::Parcel::LayoutDetector::FILE_PATTERN

      TYPE_BY_PREFIX = {
        "CLASS"      => :class,
        "PROPERTY"   => :property,
        "RELATION"   => :relation,
        "UNIT"       => :unit,
        "VALUELIST"  => :value_list,
        "VALUETERMS" => :value_term,
      }.freeze

      attr_reader :path

      def initialize(path)
        @path = path
      end

      def read_workbook
        files = legacy_files
        raise "No legacy export_*.xls files found in #{@path.inspect}" if files.empty?

        sheets = files.map { |f| read_one(f) }.compact
        sheetmap = files.map { |f| sheetmap_entry_for(f) }.compact

        parcel_id = files.first && File.basename(files.first).split("_").last&.sub(/\.\w+\z/, "")
        project = Opencdd::Parcel::Workbook::ProjectInfo.new(
          project_id: "LOCAL",
          parcel_id: parcel_id,
          multi_language: "",
          base_language: "en",
        )

        Opencdd::Parcel::Workbook.new(
          sheets: sheets,
          sheetmap: sheetmap,
          project: project,
          source_path: @path.to_s,
        )
      end

      def load_into(database)
        workbook = read_workbook
        database.add_workbook(workbook)
        database.finalize!
        database
      end

      private

      def legacy_files
        if File.directory?(@path)
          Dir.children(@path).sort.map { |f| File.join(@path, f) }
            .select { |f| File.file?(f) && File.basename(f) =~ FILE_PATTERN }
        elsif File.file?(@path) && File.basename(@path) =~ FILE_PATTERN
          [@path.to_s]
        else
          []
        end
      end

      def read_one(file)
        prefix = File.basename(file).sub(/\Aexport_/, "").split("_", 2).first
        type = TYPE_BY_PREFIX[prefix]
        warn "Unknown legacy file prefix: #{file}" unless type
        return nil unless type

        sheet_name = File.basename(file, ".*")
        rows = read_rows(file)
        Opencdd::Parcel::Sheet.from_rows(rows.each, name: sheet_name)
      end

      def read_rows(file)
        ext = File.extname(file).downcase
        if ext == ".xls"
          read_xls_rows(file)
        else
          read_xlsx_rows(file)
        end
      end

      def read_xls_rows(file)
        require "spreadsheet"
        book = Spreadsheet.open(file)
        sheet = book.worksheet(0) || book.worksheets.first
        sheet.rows.map do |row|
          row.to_a
        end
      end

      def read_xlsx_rows(file)
        require "roo"
        roo = Roo::Spreadsheet.open(file, extension: :xlsx)
        target = roo.sheets.first || "Export"
        sheet = roo.sheet(target)
        (1..sheet.last_row.to_i).map { |i| sheet.row(i) }
      end

      def sheetmap_entry_for(file)
        prefix = File.basename(file).sub(/\Aexport_/, "").split("_", 2).first
        type = TYPE_BY_PREFIX[prefix]
        return nil unless type
        meta_class_code = Opencdd::Parcel::TYPE_TO_META_CLASS[type]
        return nil unless meta_class_code

        Opencdd::Parcel::Workbook::SheetMapEntry.new(
          project_id: "LOCAL",
          parcel_id: nil,
          class_irdi: Opencdd::IRDI.parse("0112/2///62656_1##{meta_class_code}"),
          content_no: 0,
          sheet_no: nil,
          sheet_name: File.basename(file, ".*"),
          type: prefix,
          target: "",
        )
      end
    end
  end
end
