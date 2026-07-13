# frozen_string_literal: true

module Opencdd
  module Parcel
    class Sheet
      DEFAULT_REQUIREMENT_FOR_CODE = "KEY".freeze
      DEFAULT_REQUIREMENT_OTHER   = "OPT".freeze
      DEFAULT_SOURCE_LANGUAGE     = "en".freeze

      attr_reader :name, :metadata, :schema, :rows, :raw_row_count

      def self.scaffold(meta_class_irdi:, parcel_id:, source_language: DEFAULT_SOURCE_LANGUAGE,
                        translation_languages: [], sheet_name: nil)
        meta = Opencdd::MetaClasses.for(meta_class_irdi.to_s) or
          raise ArgumentError, "unknown meta-class #{meta_class_irdi}"

        code_property_id = Opencdd::MetaClasses.code_property_id_for(meta.irdi)
        languages = ([source_language] + translation_languages).map(&:to_s).uniq

        columns = meta.allowed_property_ids.each_with_index.map do |property_id, idx|
          SheetSchema::Column.new(
            index: idx + 1,
            property_id: property_id,
            name_by_lang: languages.to_h { |l| [l, display_name_for(property_id, l)] },
            datatype: default_datatype_for(property_id),
            value_format: nil,
            pattern: nil,
            requirement: property_id == code_property_id ? DEFAULT_REQUIREMENT_FOR_CODE : DEFAULT_REQUIREMENT_OTHER,
          )
        end

        schema = SheetSchema.new
        columns.each do |col|
          schema.add_column(col)
        end
        schema.finalize_for_scaffold!

        metadata = Metadata.new
        metadata.add("#CLASS_ID := #{meta.irdi}")
        metadata.add("#CLASS_NAME.#{source_language} := #{meta.name}")
        metadata.add("#SOURCE_LANGUAGE := #{source_language}")
        unless translation_languages.empty?
          metadata.add("#TRANSLATION_LANGUAGE := #{translation_languages.join(',')}")
        end

        name = sheet_name || "#{parcel_id}_#{meta.name.upcase}"
        new(name: name, metadata: metadata, schema: schema, raw_rows: [])
      end

      def self.display_name_for(property_id, _lang)
        entry = Opencdd::PropertyIds::REGISTRY[property_id.to_s]
        return property_id.to_s unless entry
        entry.aliases.first || property_id.to_s
      end

      def self.default_datatype_for(property_id)
        entry = Opencdd::PropertyIds::REGISTRY[property_id.to_s]
        return nil unless entry
        case entry.value_kind
        when :identifier_ref, :class_ref then "ICID_STRING"
        when :set_of_refs                 then "ICID_STRING"
        when :date                        then "DATE_TYPE"
        when :date_time                   then "DATE_TIME_TYPE"
        when :condition                   then "STRING_TYPE"
        else "STRING_TYPE"
        end
      end

      def self.from_rows(rows, name: nil)
        metadata = Opencdd::Parcel::Metadata.new
        header_rows = []
        data_rows = []

        rows.each do |raw_row|
          row = Array(raw_row)
          first_cell = row.first&.to_s&.strip.to_s

          if first_cell.start_with?("#") && first_cell.include?(":=")
            metadata.add(first_cell)
            next
          end

          if first_cell.start_with?("#")
            header_rows << row
            next
          end

          if row_has_data?(row)
            data_rows << row
          end
        end

        schema = Opencdd::Parcel::SheetSchema.from_header_rows(header_rows)
        new(name: name, metadata: metadata, schema: schema, raw_rows: data_rows)
      end

      def self.row_has_data?(row)
        row.each_with_index do |v, i|
          next if i.zero?
          next if v.nil?
          s = v.to_s.strip
          return true unless s.empty?
        end
        false
      end

      def initialize(name:, metadata:, schema:, raw_rows:)
        @name = name
        @metadata = metadata
        @schema = schema
        @raw_row_count = raw_rows.size
        @rows = build_rows(raw_rows)
        freeze
      end

      def meta_class_irdi
        @metadata.meta_class_irdi
      end

      def meta_class_code
        @metadata.meta_class_code
      end

      def type
        @metadata.type
      end

      def each(&block)
        @rows.each(&block)
      end

      include Enumerable

      def size
        @rows.size
      end

      alias_method :count, :size
      alias_method :length, :size

      def first
        @rows.first
      end

      def last
        @rows.last
      end

      def entities(database = nil)
        EntitiesProxy.new(self, database)
      end

      def apply_default_values!(property_id:)
        col = @schema.find_by_property_id(property_id.to_s)
        return if col.nil? || col.default_value.nil?
        storage_key = storage_key_for(col)
        @rows.each do |row|
          current = row[storage_key]
          next if !current.nil? && !current.to_s.empty?
          row[storage_key] = col.default_value
        end
        self
      end

      def apply_all_default_values!
        @schema.columns.each do |col|
          next if col.default_value.nil?
          apply_default_values!(property_id: col.property_id)
        end
        self
      end

      def merge_rows_from(other)
        unless meta_codes_match?(meta_class_irdi, other.meta_class_irdi)
          raise ArgumentError,
                "meta-class mismatch: #{meta_class_irdi} vs #{other.meta_class_irdi}"
        end
        other.rows.each do |src|
          new_row = src.reject { |k, _| k == "__row_index__" }
          next if new_row.empty?
          new_row["__row_index__"] = @rows.size
          @rows << new_row
        end
        self
      end

      def dup_with(name:)
        raw_rows = @rows.map { |row| row_to_array(row) }
        self.class.new(name: name, metadata: @metadata, schema: @schema, raw_rows: raw_rows)
      end

      private

      def meta_codes_match?(a, b)
        return false if a.nil? || b.nil?
        a.to_s.split("#").last == b.to_s.split("#").last
      end

      def row_to_array(row)
        array = Array.new(@schema.columns.map(&:index).max.to_i + 1)
        @schema.columns.each do |col|
          key = storage_key_for(col)
          val = row[key]
          array[col.index] = val if val
        end
        array
      end

      def build_rows(raw_rows)
        seen = {}
        result = []
        raw_rows.each do |row|
          instance = build_instance(row)
          next unless instance
          key = instance["__row_index__"] = result.size
          result << instance
          seen[key] = true
        end
        result
      end

      def build_instance(row)
        h = {}
        any_value = false
        @schema.columns.each do |col|
          v = row[col.index]
          next if v.nil?
          s = value_to_string(v)
          next if s.empty?
          key = storage_key_for(col)
          h[key] = s
          any_value = true
        end

        return nil unless any_value
        h["__row_index__"] = nil
        h
      end

      def storage_key_for(col)
        pid = col.property_id
        return pid if pid.include?(".")
        entry = Opencdd::PropertyIds::REGISTRY[pid]
        return pid unless entry&.multilingual
        langs = (col.name_by_lang || {}).keys
        return pid if langs.size != 1
        "#{pid}.#{langs.first}"
      end

      def value_to_string(v)
        return "" if v.nil?
        case v
        when String then v.strip
        when Float
          if v == v.to_i
            v.to_i.to_s
          else
            v.to_s
          end
        when Integer then v.to_s
        when Date, Time then v.iso8601
        when Symbol then v.to_s
        else v.to_s
        end
      end

      class EntitiesProxy
        attr_reader :sheet, :database

        def initialize(sheet, database)
          @sheet = sheet
          @database = database
        end

        def each
          return enum_for(:each) unless block_given?

          sheet.each do |row|
            yield row
          end
        end

        include Enumerable
      end
    end
  end
end
