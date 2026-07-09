# frozen_string_literal: true

require "csv"
require "stringio"

module Cdd
  module Parcel
    module CsvWriter
      DEFAULT_ENCODING = "UTF-8".freeze

      def self.write_sheet(sheet, entities, target, source_language: SheetEmitter::DEFAULT_SOURCE_LANGUAGE, encoding: DEFAULT_ENCODING, write_bom: false)
        emitter = SheetEmitter.new(source_language: source_language)
        rows = emitter.emit_data_rows(sheet, entities)
        data_rows = rows.map { |row| row.drop(1) }
        write_csv(target, data_rows, encoding: encoding, write_bom: write_bom)
        target
      end

      def self.write_workbook(database, dir, parcel_id:, source_language: SheetEmitter::DEFAULT_SOURCE_LANGUAGE, encoding: DEFAULT_ENCODING, write_bom: false)
        require "fileutils"
        FileUtils.mkdir_p(dir)

        built_sheets = build_sheets(database, parcel_id, source_language)
        paths = []
        built_sheets.each do |built|
          filename = "#{parcel_id}_#{type_label(built.type)}.csv"
          path = File.join(dir, filename)
          write_sheet(built.sheet, built.entities, path,
                      source_language: source_language, encoding: encoding, write_bom: write_bom)
          paths << path
        end
        paths
      end

      class BuiltSheet < Struct.new(:sheet, :entities, :type, keyword_init: true); end

      def self.build_sheets(database, parcel_id, source_language)
        if database.workbooks.any?
          source_workbook = database.workbooks.first
          sheets_by_type = source_workbook.sheets.select { |s| s.type }.group_by(&:type)
          sheets_by_type.map do |type, sheets|
            primary = sheets.first
            entities = database.entities_of_type(primary.type)
            BuiltSheet.new(sheet: primary, entities: entities, type: type)
          end
        else
          types = %i[class property value_list value_term unit relation view_control]
          types.filter_map do |type|
            meta_code = Cdd::MetaClasses.meta_class_for_type(type)
            next nil unless meta_code
            sheet = Cdd::Parcel::Sheet.scaffold(
              meta_class_irdi: meta_code,
              parcel_id: parcel_id,
              source_language: source_language,
            )
            entities = database.entities_of_type(type)
            BuiltSheet.new(sheet: sheet, entities: entities, type: type)
          end
        end
      end
      private_class_method :build_sheets

      def self.type_label(type)
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
      private_class_method :type_label

      def self.write_csv(target, rows, encoding:, write_bom:)
        case target
        when String then write_csv_to_path(target, rows, encoding, write_bom)
        when Pathname then write_csv_to_path(target.to_s, rows, encoding, write_bom)
        when IO, StringIO then write_csv_to_io(target, rows, encoding, write_bom)
        else
          raise ArgumentError, "unsupported CSV target: #{target.inspect} (expected String, Pathname, IO, or StringIO)"
        end
      end
      private_class_method :write_csv

      def self.write_csv_to_path(path, rows, encoding, write_bom)
        File.open(path, "w:#{encoding}") do |f|
          write_bom_prefix(f, encoding) if write_bom
          write_csv_to_io(f, rows, encoding, write_bom)
        end
      end
      private_class_method :write_csv_to_path

      def self.write_csv_to_io(io, rows, _encoding, _write_bom)
        rows.each do |row|
          line = CSV.generate_line(row || [])
          io.write(line)
        end
      end
      private_class_method :write_csv_to_io

      def self.write_bom_prefix(io, encoding)
        bom = case encoding.upcase
              when "UTF-8", "UTF8" then "\xEF\xBB\xBF"
              when "UTF-16LE" then "\xFF\xFE"
              when "UTF-16BE" then "\xFE\xFF"
              end
        io.write(bom) if bom
      end
      private_class_method :write_bom_prefix
    end
  end
end
