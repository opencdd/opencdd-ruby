# frozen_string_literal: true

module Opencdd
  module Parcel
    class SheetEmitter
      DEFAULT_SOURCE_LANGUAGE = "en".freeze

      META_DIRECTIVE_ORDER = %w[
        CLASS_ID ALTERNATE_CLASSID SUPER_ALT_CLASSID SUB_ALT_CLASSID
        CLASS_NAME CLASS_DEFINITION CLASS_NOTE
        SOURCE_LANGUAGE PARCEL_MODE PARCEL_ID PARCEL_CC
        DEFAULT_SUPPLIER DEFAULT_VERSION
        ID_ENCODE DELIMITER DECIMAL OBJECT_ID_NAME
        TRANSLATION_LANGUAGE
      ].freeze

      HEADER_DIRECTIVE_ORDER = %w[
        PROPERTY_ID ALTERNATE_ID SUPER_ALTERNATE_ID SUB_ALTERNATE_ID EQUIVALENT_ID
        SUPER_PROPERTY
        DATATYPE UNIT VARIABLE_PREFIX_UNIT UNIT_ID ALTERNATIVE_UNITS
        VALUE_FORMAT PATTERN RELATION DEFAULT_VALUE
        DEFAULT_DATA_SUPPLIER DEFAULT_DATA_VERSION REQUIREMENT
      ].freeze

      MULTILINGUAL_DIRECTIVES = %w[PROPERTY_NAME DEFINITION NOTE].freeze

      attr_reader :source_language

      def initialize(source_language: "en")
        @source_language = source_language.to_s
      end

      def emit(sheet, entities)
        rows = []
        emit_metadata_rows(sheet, rows)
        emit_header_rows(sheet, rows)
        entities.each { |e| emit_data_row(sheet, e, rows) }
        rows
      end

      def emit_data_rows(sheet, entities)
        rows = []
        entities.each { |e| emit_data_row(sheet, e, rows) }
        rows
      end

      private

      def emit_metadata_rows(sheet, rows)
        present = sheet.metadata.directives.transform_keys(&:to_s)
        META_DIRECTIVE_ORDER.each do |base|
          emit_meta_base(present, base, rows)
        end
      end

      def emit_meta_base(present, base, rows)
        matched = present.select { |k, _| k == base || k.start_with?("#{base}.") }
        if matched.empty?
          rows << ["##{base}:="]
          return
        end
        matched.each do |key, val|
          rows << ["##{key}:=#{val}"]
        end
      end

      def emit_header_rows(sheet, rows)
        present = column_directives_from(sheet)
        HEADER_DIRECTIVE_ORDER.each do |name|
          emit_directive_row(present, name, rows)
        end
        MULTILINGUAL_DIRECTIVES.each do |base|
          present.keys.select { |k| k == base || k.start_with?("#{base}.") }.sort.each do |key|
            emit_directive_row(present, key, rows)
          end
        end
      end

      def column_directives_from(sheet)
        cols = sheet.schema.columns
        {}.tap do |h|
          HEADER_DIRECTIVE_ORDER.each do |name|
            vals = cols.map { |col| column_scalar_value(col, name) }
            h[name] = vals
          end
          MULTILINGUAL_DIRECTIVES.each do |base|
            langs = cols.flat_map { |col| langs_for(col, base) }.uniq
            langs.each do |lang|
              h["#{base}.#{lang}"] = cols.map { |col| localized_value(col, base, lang) }
            end
          end
        end
      end

      def emit_directive_row(present, name, rows)
        values = present[name]
        rows << ["##{name}", *(values || [])]
      end

      def column_scalar_value(col, name)
        case name
        when "PROPERTY_ID"           then col.raw_property_id || col.property_id
        when "ALTERNATE_ID"          then col.alternate_id
        when "SUPER_ALTERNATE_ID"    then col.super_alternate_id
        when "SUB_ALTERNATE_ID"      then col.sub_alternate_id
        when "EQUIVALENT_ID"         then col.equivalent_id
        when "SUPER_PROPERTY"        then col.super_property
        when "DATATYPE"              then col.datatype
        when "UNIT"                  then col.unit
        when "VARIABLE_PREFIX_UNIT"  then col.variable_prefix_unit
        when "UNIT_ID"               then col.unit_id
        when "ALTERNATIVE_UNITS"     then col.alternative_units
        when "VALUE_FORMAT"          then col.value_format
        when "PATTERN"               then col.pattern
        when "RELATION"              then col.relation
        when "DEFAULT_VALUE"         then col.default_value
        when "DEFAULT_DATA_SUPPLIER" then col.default_data_supplier
        when "DEFAULT_DATA_VERSION"  then col.default_data_version
        when "REQUIREMENT"           then col.requirement
        end
      end

      def langs_for(col, base)
        case base
        when "PROPERTY_NAME" then (col.name_by_lang || {}).keys
        when "DEFINITION"    then (col.definition_by_lang || {}).keys
        when "NOTE"          then (col.note_by_lang || {}).keys
        else []
        end
      end

      def localized_value(col, base, lang)
        case base
        when "PROPERTY_NAME" then (col.name_by_lang || {})[lang]
        when "DEFINITION"    then (col.definition_by_lang || {})[lang]
        when "NOTE"          then (col.note_by_lang || {})[lang]
        end
      end

      def emit_data_row(sheet, entity, rows)
        values = sheet.schema.columns.map { |col| entity_value_for(entity, col) }
        rows << [nil, *values]
      end

      def entity_value_for(entity, col)
        pid = col.property_id
        val = entity.properties[pid]
        return val unless val.nil?
        multilingual_lookup(entity, pid)
      end

      # Multilingual fallback. The raw properties hash is the
      # canonical store; the lookup here mirrors FieldReader's
      # raw_multilingual resolution (single source of truth for
      # "where do I find the language-tagged variant of this field").
      # Routed through Entity#read_field when the column maps to a
      # declared field, so any future field-DTL changes apply here
      # too — see TODO.impl/26.
      def multilingual_lookup(entity, pid)
        entry = Opencdd::PropertyIds::REGISTRY[pid]
        return entity.properties["#{pid}.#{@source_language}"] if entry && entry.multilingual
        if pid.include?(".")
          base, = pid.split(".", 2)
          return entity.properties[pid] if entity.properties.key?(pid)
          return entity.properties[base]
        end
        nil
      end
    end
  end
end
