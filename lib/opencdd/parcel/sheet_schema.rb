# frozen_string_literal: true

module Opencdd
  module Parcel
    class SheetSchema
      # Parcel-specific column-ID canonicalization. Maps the
      # ParcelMaker variant headers (MDC_P004_1, MDC_P005, ...)
      # to the canonical IEC 61360 IDs (MDC_P004, MDC_P006, ...).
      #
      # Owned by SheetSchema because this mapping only exists for
      # the Parcel sheet layout — the PropertyIds registry is
      # ontology-only and shouldn't carry format-specific details.
      VARIANT_TO_CANONICAL = {
        "MDC_P004_1" => "MDC_P004",
        "MDC_P004_2" => "MDC_P007",
        "MDC_P004_3" => "MDC_P005",
        "MDC_P005"   => "MDC_P006",
        "MDC_P007_1" => "MDC_P008",
        "MDC_P007_2" => "MDC_P009",
      }.freeze

      # Canonicalize a Parcel column ID. Splits language tags
      # (<id>.<lang>) so they round-trip cleanly. Returns the
      # canonical ID (or the input unchanged if no mapping exists).
      def self.canonical_id(raw_id)
        return nil if raw_id.nil?
        s = raw_id.to_s.strip
        return nil if s.empty?
        match = s.match(/\.(?<lang>[A-Za-z0-9-]+)\z/)
        base = match ? match.pre_match : s
        lang = match && match[:lang]
        canonical = VARIANT_TO_CANONICAL[base] || base
        lang ? "#{canonical}.#{lang}" : canonical
      end

      DIRECTIVE_ROWS = %w[
        PROPERTY_ID
        ALTERNATE_ID
        SUPER_ALTERNATE_ID
        SUB_ALTERNATE_ID
        EQUIVALENT_ID
        SUPER_PROPERTY
        PROPERTY_NAME
        DEFINITION
        NOTE
        DATATYPE
        UNIT
        VARIABLE_PREFIX_UNIT
        UNIT_ID
        ALTERNATIVE_UNITS
        VALUE_FORMAT
        PATTERN
        RELATION
        DEFAULT_VALUE
        DEFAULT_DATA_SUPPLIER
        DEFAULT_DATA_VERSION
        REQUIREMENT
      ].freeze

      class Column < Struct.new(
        :index,
        :property_id,
        :raw_property_id,
        :alternate_id,
        :super_alternate_id,
        :sub_alternate_id,
        :equivalent_id,
        :super_property,
        :name_by_lang,
        :definition_by_lang,
        :note_by_lang,
        :datatype,
        :unit,
        :variable_prefix_unit,
        :unit_id,
        :alternative_units,
        :value_format,
        :pattern,
        :relation,
        :default_value,
        :default_data_supplier,
        :default_data_version,
        :requirement,
        keyword_init: true,
      )
        def name(lang = :en)
          name_by_lang[lang.to_s]
        end

        def definition(lang = :en)
          definition_by_lang[lang.to_s]
        end

        def note(lang = :en)
          note_by_lang[lang.to_s]
        end

        def required?
          requirement == "MAND"
        end

        def key?
          requirement == "KEY"
        end

        def obsolete?
          requirement == "OBS"
        end
      end

      DIRECTIVE_ROW_PREFIX = "#".freeze

      attr_reader :columns, :columns_by_id, :column_directives

      def initialize
        @columns = []
        @columns_by_id = {}
        @column_directives = {}
      end

      def self.from_header_rows(rows)
        schema = new
        rows.each do |row|
          schema.add_directive_row(row)
        end
        schema.finalize!
        schema
      end

      def add_directive_row(row)
        return self if row.nil? || row.empty?

        label_cell = row[0].to_s
        directive = parse_directive(label_cell)
        return self unless directive

        values = row[1..].to_a

        unless @column_directives.key?(directive)
          @column_directives[directive] = []
        end

        values.each_with_index do |val, idx|
          @column_directives[directive][idx] = val
        end

        self
      end

      def add_column(column)
        @columns << column
        @columns_by_id[column.property_id] = column
        self
      end

      def finalize_for_scaffold!
        freeze
      end

      def finalize!
        ids = @column_directives["PROPERTY_ID"] || []
        ids.each_with_index do |id, idx|
          next if id.nil? || id.to_s.strip.empty?

          col = Column.new(
            index: idx + 1,
            property_id: Opencdd::Parcel::SheetSchema.canonical_id(id.to_s.strip),
            raw_property_id: id.to_s.strip,
            alternate_id: lookup("ALTERNATE_ID", idx),
            super_alternate_id: lookup("SUPER_ALTERNATE_ID", idx),
            sub_alternate_id: lookup("SUB_ALTERNATE_ID", idx),
            equivalent_id: lookup("EQUIVALENT_ID", idx),
            super_property: lookup("SUPER_PROPERTY", idx),
            name_by_lang: lang_hash_for("PROPERTY_NAME", idx),
            definition_by_lang: lang_hash_for("DEFINITION", idx),
            note_by_lang: lang_hash_for("NOTE", idx),
            datatype: lookup("DATATYPE", idx),
            unit: lookup("UNIT", idx),
            variable_prefix_unit: lookup("VARIABLE_PREFIX_UNIT", idx),
            unit_id: lookup("UNIT_ID", idx),
            alternative_units: lookup("ALTERNATIVE_UNITS", idx),
            value_format: lookup("VALUE_FORMAT", idx),
            pattern: lookup("PATTERN", idx),
            relation: lookup("RELATION", idx),
            default_value: lookup("DEFAULT_VALUE", idx),
            default_data_supplier: lookup("DEFAULT_DATA_SUPPLIER", idx),
            default_data_version: lookup("DEFAULT_DATA_VERSION", idx),
            requirement: lookup("REQUIREMENT", idx),
          )
          @columns << col
          @columns_by_id[col.property_id] = col
        end

        freeze
      end

      def [](property_id_or_name)
        find_by_property_id(property_id_or_name) || find_by_name(property_id_or_name)
      end

      def find_by_property_id(id)
        @columns_by_id[id.to_s]
      end

      def find_by_name(name, lang = :en)
        @columns.find { |c| c.name(lang).to_s.casecmp(name.to_s).zero? }
      end

      def size
        @columns.size
      end

      def each(&block)
        @columns.each(&block)
      end

      include Enumerable

      private

      def parse_directive(cell)
        return nil if cell.nil?
        s = cell.to_s.strip
        return nil unless s.start_with?("#")
        s[1..]
      end

      def lookup(directive, col_idx)
        vals = @column_directives[directive]
        return nil unless vals
        v = vals[col_idx]
        return nil if v.nil?
        s = v.to_s.strip
        s.empty? ? nil : s
      end

      def lang_hash_for(directive, col_idx)
        h = {}
        @column_directives.each do |key, vals|
          base, lang = key.split(".", 2)
          next unless base == directive
          v = vals[col_idx]
          next if v.nil?
          s = v.to_s.strip
          next if s.empty?
          lang = "en" if lang.nil? || lang.empty?
          h[lang] = s
        end
        h
      end
    end
  end
end
