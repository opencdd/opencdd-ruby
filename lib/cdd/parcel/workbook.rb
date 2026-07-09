# frozen_string_literal: true

require "set"

module Cdd
  module Parcel
    class Workbook
      SheetMapEntry = Struct.new(:project_id, :parcel_id, :class_irdi, :content_no,
                                 :sheet_no, :sheet_name, :type, :target, keyword_init: true)
      ProjectInfo = Struct.new(:project_id, :parcel_id, :multi_language, :base_language,
                               keyword_init: true)

      HEADER_ROW_NAMES = %i[
        class_id class_name source_language translation_language
        property_id property_name datatype value_format pattern
        default_value requirement unit
      ].freeze

      MANDATORY_HEADER_ROWS = %i[class_id property_id].freeze

      attr_reader :sheets, :sheetmap, :project, :source_path

      def initialize(sheets:, sheetmap: [], project: nil, source_path: nil,
                     hidden_header_rows: nil)
        @sheets = sheets
        @sheetmap = sheetmap
        @project = project
        @source_path = source_path
        @hidden_header_rows = validate_hidden(hidden_header_rows)
        reindex
        freeze
      end

      def hidden_header_rows
        @hidden_header_rows.dup
      end

      def hide_header_row!(name)
        sym = name.to_sym
        raise ArgumentError, "unknown header row: #{sym.inspect}" unless HEADER_ROW_NAMES.include?(sym)
        raise ArgumentError, "cannot hide mandatory header row: #{sym.inspect}" if MANDATORY_HEADER_ROWS.include?(sym)
        @hidden_header_rows << sym
        self
      end

      def show_header_row!(name)
        @hidden_header_rows.delete(name.to_sym)
        self
      end

      def register_sheet(sheet)
        raise ArgumentError, "sheet already registered: #{sheet.name}" if @sheets_by_name.key?(sheet.name.to_s)
        @sheets << sheet
        @sheets_by_name[sheet.name.to_s] = sheet
        @sheetmap << SheetMapEntry.new(
          project_id: @project&.project_id || "LOCAL",
          parcel_id:  @project&.parcel_id,
          class_irdi: sheet.meta_class_irdi,
          content_no: 0,
          sheet_no:   @sheets.size,
          sheet_name: sheet.name,
          type:       parcel_type_label_for(sheet.type),
          target:     "",
        )
        self
      end

      def import_into(sheet_name, file_path, format: nil)
        target = sheet(sheet_name)
        raise ArgumentError, "unknown sheet: #{sheet_name.inspect}" unless target

        format ||= detect_format(file_path)
        temp = read_external_sheet(file_path, format, target.meta_class_irdi)
        unless meta_codes_match?(target.meta_class_irdi, temp.meta_class_irdi)
          raise ArgumentError,
                "meta-class mismatch: target=#{target.meta_class_irdi} source=#{temp.meta_class_irdi}"
        end
        target.merge_rows_from(temp)
        self
      end

      def sheet(name)
        @sheets_by_name[name.to_s]
      end

      def sheets_of_type(type)
        type = type.to_sym
        @sheets.select { |s| s.type == type }
      end

      def class_sheet      ; sheets_of_type(:class).first      ; end
      def property_sheet   ; sheets_of_type(:property).first   ; end
      def unit_sheet       ; sheets_of_type(:unit).first       ; end
      def value_list_sheet ; sheets_of_type(:value_list).first ; end
      def value_term_sheet ; sheets_of_type(:value_term).first ; end
      def relation_sheet   ; sheets_of_type(:relation).first   ; end
      def view_control_sheet; sheets_of_type(:view_control).first; end

      def each_sheet(&block)
        @sheets.each(&block)
      end

      def parcel_id
        @project&.parcel_id
      end

      def project_id
        @project&.project_id
      end

      def base_language
        @project&.base_language || "en"
      end

      def merge(other)
        merged_sheets = @sheets + other.sheets
        merged_map    = @sheetmap + other.sheetmap
        merged_proj   = @project || other.project
        Workbook.new(sheets: merged_sheets, sheetmap: merged_map, project: merged_proj,
                     source_path: @source_path)
      end

      private

      def validate_hidden(rows)
        return Set.new if rows.nil?
        set = rows.to_set
        invalid = set - HEADER_ROW_NAMES.to_set
        raise ArgumentError, "unknown header rows: #{invalid.to_a.inspect}" unless invalid.empty?
        mandatory = set & MANDATORY_HEADER_ROWS.to_set
        raise ArgumentError, "cannot hide mandatory rows: #{mandatory.to_a.inspect}" unless mandatory.empty?
        set
      end

      def detect_format(path)
        case File.extname(path.to_s).downcase
        when ".csv" then :csv
        when ".txt" then :csv_tab
        when ".xlsx", ".xlsm" then :xlsx
        when ".xls" then :xls
        else raise ArgumentError, "cannot detect format for: #{path.inspect}"
        end
      end

      def read_external_sheet(path, format, meta_class_irdi)
        case format
        when :csv      then Cdd::Parcel::CsvReader.read(path, meta_class_irdi: meta_class_irdi)
        when :csv_tab  then Cdd::Parcel::CsvReader.read(path, meta_class_irdi: meta_class_irdi, col_sep: "\t")
        when :xlsx, :xls
          Cdd::Parcel::WorkbookReader.new(path).read_workbook.sheets.first
        else raise ArgumentError, "unknown format: #{format.inspect}"
        end
      end

      def parcel_type_label_for(type)
        return nil if type.nil?
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

      def meta_codes_match?(a, b)
        return false if a.nil? || b.nil?
        a_code = a.to_s.split("#").last
        b_code = b.to_s.split("#").last
        a_code == b_code
      end

      def reindex
        @sheets_by_name = @sheets.to_h { |s| [s.name.to_s, s] }
      end
    end
  end
end
