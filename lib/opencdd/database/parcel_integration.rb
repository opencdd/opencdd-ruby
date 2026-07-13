# frozen_string_literal: true

module Opencdd
  class Database
    # Parcel workbook ingestion and dictionary lifecycle (add/drop/
    # register_external). Sheetmap construction and translation-
    # language parsing.
    module ParcelIntegration
      def add_workbook(workbook)
        @workbooks << workbook
        parcel_id = workbook.parcel_id
        workbook.each_sheet do |sheet|
          next unless sheet.type && sheet.rows.any?
          type = sheet.type
          entity_class = Opencdd::MetaClasses.entity_class_for_type(type)
          raise "Unknown entity type #{type.inspect} for sheet #{sheet.name.inspect}" unless entity_class

          sheet.rows.each do |row|
            entity = entity_class.from_row(
              row,
              schema: sheet.schema,
              meta_class_irdi: sheet.meta_class_irdi,
            )
            add_entity(entity)
            if parcel_id && entity.irdi
              prev = @entity_sources[entity.irdi]
              @entity_sources[entity.irdi] = prev.nil? ? parcel_id : prev
            end
          end
        end
        self
      end

      def add_dictionary(dict)
        validate_parcel_id!(dict.parcel_id)
        source_language = dict.source_language || "en"
        translation_languages = Array(dict.translation_languages)
        meta_irdis = normalize_meta_class_irdis(dict.meta_class_irdis)

        sheets = meta_irdis.map do |meta_irdi|
          Opencdd::Parcel::Sheet.scaffold(
            meta_class_irdi: meta_irdi,
            parcel_id: dict.parcel_id,
            source_language: source_language,
            translation_languages: translation_languages,
          )
        end

        project = Opencdd::Parcel::Workbook::ProjectInfo.new(
          project_id: dict.parcel_id,
          parcel_id:  dict.parcel_id,
          multi_language: translation_languages.join(","),
          base_language: source_language,
        )
        sheetmap = build_sheetmap_for(dict.parcel_id, sheets)
        workbook = Opencdd::Parcel::Workbook.new(
          sheets: sheets, sheetmap: sheetmap, project: project,
        )
        @workbooks << workbook
        workbook
      end

      def drop_dictionary(parcel_id)
        matching = @workbooks.select { |wb| wb.parcel_id == parcel_id }
        raise ArgumentError, "no dictionary with parcel_id #{parcel_id.inspect}" if matching.empty?

        irdis_to_drop = @entity_sources.select { |_, pid| pid == parcel_id }.keys
        irdis_to_drop.each do |irdi|
          remove_entity_by_irdi!(irdi)
          @entity_sources.delete(irdi)
        end
        @workbooks.reject! { |wb| wb.parcel_id == parcel_id }
        self
      end

      def register_external_sheet(sheet, parcel_id:)
        validate_parcel_id!(parcel_id)
        wb = @workbooks.find { |w| w.parcel_id == parcel_id }
        if wb.nil?
          project = Opencdd::Parcel::Workbook::ProjectInfo.new(
            project_id: parcel_id, parcel_id: parcel_id,
            multi_language: "", base_language: "en",
          )
          wb = Opencdd::Parcel::Workbook.new(sheets: [], sheetmap: [], project: project)
          @workbooks << wb
        end
        wb.register_sheet(sheet)
        self
      end

      def dictionaries
        @workbooks.map do |wb|
          Dictionary.new(
            parcel_id: wb.parcel_id,
            source_language: wb.base_language,
            translation_languages: parse_translation_languages(wb),
            meta_class_irdis: wb.sheets.map(&:meta_class_irdi).compact.uniq,
          )
        end
      end

      private

      def validate_parcel_id!(parcel_id)
        unless parcel_id.is_a?(String) && parcel_id.match?(PARCEL_ID_PATTERN)
          raise ArgumentError, "invalid parcel_id: #{parcel_id.inspect}"
        end
      end

      def normalize_meta_class_irdis(raw)
        codes = Array(raw).map { |v| v.to_s.split("#").last }
        FORCED_META_CLASSES.each { |c| codes << c unless codes.include?(c) }
        codes.uniq
      end

      def build_sheetmap_for(parcel_id, sheets)
        entries = [
          Opencdd::Parcel::Workbook::SheetMapEntry.new(
            project_id: parcel_id, parcel_id: parcel_id, class_irdi: nil,
            content_no: 0, sheet_no: 2, sheet_name: "pcls_LOCAL",
            type: "PARCEL_LIST", target: "",
          ),
        ]
        sheets.each_with_index do |sheet, idx|
          entries << Opencdd::Parcel::Workbook::SheetMapEntry.new(
            project_id: parcel_id, parcel_id: parcel_id,
            class_irdi: sheet.meta_class_irdi,
            content_no: 0, sheet_no: idx + 3,
            sheet_name: sheet.name,
            type: Opencdd::MetaClasses.sheet_type_for_type(Opencdd::MetaClasses.type_for(sheet.meta_class_code)),
            target: "",
          )
        end
        entries
      end

      def parse_translation_languages(workbook)
        multi = workbook.project&.multi_language.to_s
        multi.split(",").map(&:strip).reject(&:empty?)
      end
    end
  end
end
