# frozen_string_literal: true

module Opencdd
  module Parcel
    # Reads a single Parcel workbook file (.xlsx, .xlsm, .xltx, or
    # legacy single-sheet .xls) and produces a +Opencdd::Parcel::Workbook+.
    #
    # This is the canonical IEC 62656-1 Parcel container: one file
    # with Project / sheetmap / pcls_LOCAL / data sheets. Use
    # +Opencdd::Parcel::FlatDirReader+ for the legacy 6-file-per-directory
    # layout, and +Opencdd::Parcel::ShardedDirReader+ for the per-class
    # sharded layout.
    class WorkbookReader
      LEGACY_TYPE_BY_PREFIX = {
        "CLASS"      => :class,
        "PROPERTY"   => :property,
        "RELATION"   => :relation,
        "UNIT"       => :unit,
        "VALUELIST"  => :value_list,
        "VALUETERMS" => :value_term,
        "LISTOFUNITS" => :list_of_unit,
        "DETCLASSIFICATION" => :det_classification,
      }.freeze

      LEGACY_TYPE_TO_PARCEL_NAME = {
        class:       "CLASS",
        property:    "PROPERTY",
        value_list:  "ENUM",
        value_term:  "TERMINOLOGY",
        unit:        "UoM",
        relation:    "RELATION",
        list_of_unit: "LISTOFUNITS",
        det_classification: "DETCLASSIFICATION",
      }.freeze

      META_CLASS_BY_LEGACY_TYPE = Opencdd::MetaClasses::TYPE_BY_META_CLASS.invert.freeze

      attr_reader :path

      def initialize(path)
        @path = path
      end

      def read_workbook
        sheets = []
        sheetmap = []
        project = nil

        workbook = open_workbook

        if workbook.sheet_names.include?("sheetmap")
          sheetmap = parse_sheetmap(workbook.rows_for("sheetmap"))
        end

        if workbook.sheet_names.include?("Project")
          project = parse_project(workbook.rows_for("Project"))
        end

        workbook.sheet_names.each do |sheet_name|
          next if ["Project", "sheetmap", "pcls_LOCAL"].include?(sheet_name)
          sheet = Opencdd::Parcel::Sheet.from_rows(workbook.rows_for(sheet_name).each, name: sheet_name)
          sheets << sheet if sheet
        end

        if sheets.empty? && legacy?
          sheets = [Opencdd::Parcel::Sheet.from_rows(
            workbook.rows_for(workbook.sheet_names.first).each,
            name: File.basename(@path.to_s, ".*"),
          )].compact
          sheetmap = sheets.map { |s|
            type = s.type
            next unless type
            Workbook::SheetMapEntry.new(
              project_id: project&.project_id || "LOCAL",
              parcel_id:  project&.parcel_id,
              class_irdi: Opencdd::IRDI.parse("0112/2///62656_1##{META_CLASS_BY_LEGACY_TYPE[type]}"),
              content_no: 0,
              sheet_no:   nil,
              sheet_name: s.name,
              type:       LEGACY_TYPE_TO_PARCEL_NAME[type] || type.to_s.upcase,
              target:     "",
            )
          }.compact
        end

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

      def open_workbook
        ext = File.extname(@path.to_s).downcase
        if ext == ".xls"
          SpreadsheetSource.new(@path.to_s)
        else
          RooSource.new(@path.to_s, ext)
        end
      end

      def legacy?
        File.basename(@path.to_s) =~ /\Aexport_(CLASS|PROPERTY|RELATION|UNIT|VALUELIST|VALUETERMS)_.*\z/i
      end

      def parse_sheetmap(rows)
        header = rows.first&.map { |c| c.to_s.strip.downcase } || []

        rows[1..].map do |r|
          vals = r.to_a
          h = {}
          header.each_with_index do |k, i|
            next if k.nil? || k.empty?
            v = vals[i]
            h[k.to_sym] = v.nil? || v.to_s.strip.empty? ? nil : v.to_s.strip
          end
          next unless h[:sheetname]
          Workbook::SheetMapEntry.new(
            project_id: h[:projectid],
            parcel_id:  h[:parcelid],
            class_irdi: h[:classid] && Opencdd::IRDI.parse(h[:classid]),
            content_no: h[:contentno]&.to_i,
            sheet_no:   h[:sheetno]&.to_i,
            sheet_name: h[:sheetname],
            type:       h[:type],
            target:     h[:target] || "",
          )
        end.compact
      end

      def parse_project(rows)
        header = rows.first&.map(&:to_s) || []
        vals = rows[1]&.to_a || []
        h = header.each_with_index.to_h { |k, i| [k.to_s.strip, vals[i]] }
        Workbook::ProjectInfo.new(
          project_id: h["Project ID"].to_s,
          parcel_id:  h["Parcel ID"].to_s,
          multi_language: h["Multi language"].to_s,
          base_language: (h["Base language"].to_s.empty? ? "en" : h["Base language"].to_s),
        )
      end

      class RooSource < Struct.new(:path, :extension)
        def initialize(path, ext)
          require "roo"
          roo_ext =
            case ext
            when ".xlsx" then :xlsx
            when ".xlsm" then :xlsm
            when ".xls"  then :xls
            when ".csv"  then :csv
            else :xlsx
            end
          super(path, roo_ext)
          @roo = Roo::Spreadsheet.open(path, extension: extension)
        end

        def sheet_names
          @sheet_names ||= @roo.sheets
        end

        def rows_for(name)
          sheet = @roo.sheet(name)
          (1..sheet.last_row.to_i).map { |i| sheet.row(i) }
        end
      end

      class SpreadsheetSource < Struct.new(:path)
        def initialize(path)
          require "spreadsheet"
          super(path)
          @book = Spreadsheet.open(path)
        end

        def sheet_names
          @sheet_names ||= @book.worksheets.map { |ws| decode_name(ws.name) }
        end

        def rows_for(name)
          ws = @book.worksheets.find { |w| decode_name(w.name) == name } || @book.worksheet(0)
          ws.rows.map(&:to_a)
        end

        private

        def decode_name(s)
          s.to_s.encode("UTF-8", "UTF-16LE", invalid: :replace, undef: :replace).scrub("")
        rescue Encoding::ConverterNotFoundError
          s.to_s
        end
      end
    end
  end
end
