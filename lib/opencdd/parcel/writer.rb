# frozen_string_literal: true

require "stringio"
require "set"
require "caxlsx"

module Opencdd
  module Parcel
    class Writer
      DEFAULT_PROJECT_ID = "LOCAL"
      DEFAULT_SOURCE_LANGUAGE = "en"

      attr_reader :database

      def initialize(database)
        @database = database
      end

      def write(target, parcel_id:, project_id: DEFAULT_PROJECT_ID,
                source_language: DEFAULT_SOURCE_LANGUAGE, translation_languages: [],
                sheet_types: :all, selector: nil)
        package = build_package(
          parcel_id: parcel_id, project_id: project_id,
          source_language: source_language, translation_languages: translation_languages,
          sheet_types: sheet_types, selector: selector,
        )
        serialize(package, target)
        target
      end

      def write_sheet(sheet, entities, target, source_language: DEFAULT_SOURCE_LANGUAGE)
        emitter = SheetEmitter.new(source_language: source_language)
        rows = emitter.emit(sheet, entities)
        package = Axlsx::Package.new
        package.workbook.add_worksheet(name: sheet.name) do |ws|
          rows.each { |row| ws.add_row(row) }
        end
        serialize(package, target)
        target
      end

      private

      def build_package(parcel_id:, project_id:, source_language:, translation_languages:, sheet_types:, selector: nil)
        package = Axlsx::Package.new
        workbook = package.workbook

        effective_entities = selector ? selector.resolve(@database) : nil

        built_sheets = build_sheets(
          parcel_id: parcel_id, source_language: source_language,
          translation_languages: translation_languages, sheet_types: sheet_types,
          effective_entities: effective_entities,
        )
        hidden_directives = hidden_header_rows_from_database

        add_project_sheet(workbook, parcel_id, project_id, source_language, translation_languages)
        add_sheetmap_sheet(workbook, built_sheets, parcel_id, project_id)
        add_data_sheets(workbook, built_sheets, source_language, hidden_directives)

        package
      end

      ALL_SHEET_TYPES = %i[class property value_list value_term unit relation view_control].freeze

      def resolve_types(sheet_types)
        return ALL_SHEET_TYPES if sheet_types == :all
        Array(sheet_types).map(&:to_sym)
      end

      def build_sheets(parcel_id:, source_language:, translation_languages:, sheet_types:, effective_entities: nil)
        types = resolve_types(sheet_types)
        if @database.workbooks.any?
          build_sheets_from_workbook(types, parcel_id, source_language, translation_languages, effective_entities)
        else
          build_scaffolds(types, parcel_id, source_language, translation_languages, effective_entities)
        end
      end

      def build_sheets_from_workbook(types, parcel_id, source_language, translation_languages, effective_entities)
        source_workbook = @database.workbooks.first
        picked = source_workbook.sheets.select { |s| s.type && types.include?(s.type) }
        picked.group_by(&:type).flat_map do |_type, sheets|
          primary = sheets.first
          entities = filtered_entities_of_type(primary.type, effective_entities)
          [BuiltSheet.new(sheet: primary, entities: entities, type: primary.type)]
        end
      end

      def build_scaffolds(types, parcel_id, source_language, translation_languages, effective_entities)
        types.filter_map do |type|
          meta_code = Opencdd::MetaClasses.meta_class_for_type(type)
          next nil unless meta_code
          sheet = Sheet.scaffold(
            meta_class_irdi: meta_code,
            parcel_id: parcel_id,
            source_language: source_language,
            translation_languages: translation_languages,
          )
          entities = filtered_entities_of_type(type, effective_entities)
          BuiltSheet.new(sheet: sheet, entities: entities, type: type)
        end
      end

      def filtered_entities_of_type(type, effective_entities)
        all = @database.entities_of_type(type)
        return all if effective_entities.nil?
        allowed = effective_entities.select { |e| e.type == type }.to_set
        all.select { |e| allowed.include?(e) }
      end

      def add_project_sheet(workbook, parcel_id, project_id, source_language, translation_languages)
        workbook.add_worksheet(name: "Project") do |ws|
          ws.add_row(["Project ID", "Parcel ID", "Multi language", "Base language"])
          multi = translation_languages.empty? ? "" : translation_languages.join(",")
          ws.add_row([project_id, parcel_id, multi, source_language])
        end
      end

      def add_sheetmap_sheet(workbook, built_sheets, parcel_id, project_id)
        workbook.add_worksheet(name: "sheetmap") do |ws|
          ws.add_row(%w[projectid parcelid classid contentno sheetno sheetname type target])
          ws.add_row([project_id, "", "", 0, 2, "pcls_LOCAL", "PARCEL_LIST", ""])
          built_sheets.each_with_index do |built, idx|
            sheet = built.sheet
            ws.add_row([
              project_id,
              parcel_id,
              "#{sheet.meta_class_irdi&.to_s}##1",
              0,
              idx + 3,
              sheet.name,
              parcel_type_label(built.type),
              "",
            ])
          end
        end
      end

      def parcel_type_label(type)
        Opencdd::MetaClasses.sheet_type_for_type(type) || type.to_s.upcase
      end

      def add_data_sheets(workbook, built_sheets, source_language, hidden_directives = Set.new)
        emitter = SheetEmitter.new(source_language: source_language)
        built_sheets.each do |built|
          rows = emitter.emit(built.sheet, built.entities)
          workbook.add_worksheet(name: built.sheet.name) do |ws|
            rows.each do |row|
              emitted = ws.add_row(row)
              emitted.hidden = true if row_hidden?(row, hidden_directives)
            end
          end
        end
      end

      def hidden_header_rows_from_database
        wb = @database.workbooks.first
        return Set.new unless wb
        wb.hidden_header_rows
      end

      def row_hidden?(row, hidden_directives)
        return false if hidden_directives.empty?
        first = row.first.to_s
        return false unless first.start_with?("#")
        base = first.sub(/\A#/, "").split(/[:=.]/).first
        return false if base.nil? || base.empty?
        hidden_directives.include?(base.downcase.to_sym)
      end

      def serialize(package, target)
        case target
        when String then package.serialize(target)
        when Pathname then package.serialize(target.to_s)
        when IO, StringIO then target.write(package.to_stream.read)
        else
          raise ArgumentError, "unsupported write target: #{target.inspect}"
        end
      end

      BuiltSheet = Struct.new(:sheet, :entities, :type, keyword_init: true)
    end
  end
end
