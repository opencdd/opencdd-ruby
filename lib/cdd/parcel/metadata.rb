# frozen_string_literal: true

module Cdd
  module Parcel
    class Metadata
      DIRECTIVE_REGEX = /\A#([^:=\s]+)\s*:=\s*(.*)\z/

      attr_reader :directives

      def self.from_directive(cell)
        return nil if cell.nil?
        s = cell.to_s.strip
        return nil if s.empty?
        return nil unless DIRECTIVE_REGEX.match?(s)
        new(s)
      end

      def initialize(source = nil)
        @directives = {}
        @meta_class_raw = nil
        add(source) if source
      end

      def add(cell)
        s = cell.to_s
        m = DIRECTIVE_REGEX.match(s.strip)
        return nil unless m
        key = m[1]
        val = m[2]
        @directives[key] = val
        if key == "CLASS_ID"
          @meta_class_raw = val
        end
        val
      end

      def [](key)
        @directives[key.to_s]
      end

      def key?(key)
        @directives.key?(key.to_s)
      end

      def fetch(key, default = nil, &block)
        if @directives.key?(key.to_s)
          @directives[key.to_s]
        elsif block
          yield
        else
          default
        end
      end

      def meta_class_irdi
        return @meta_class_irdi if defined?(@meta_class_irdi)
        @meta_class_irdi =
          if @meta_class_raw.nil? || @meta_class_raw.empty?
            nil
          else
            Cdd::IRDI.parse(synthesize_meta_class_irdi)
          end
      end

      def synthesize_meta_class_irdi
        raw = @meta_class_raw
        return raw if raw.include?("#")
        supplier = (@directives["DEFAULT_SUPPLIER"] || "").strip
        return raw if supplier.empty?
        "#{supplier}##{raw}"
      end

      def meta_class_code
        meta_class_irdi&.code
      end

      def type
        return @type if defined?(@type)
        code = meta_class_code
        @type = code ? Cdd::Parcel::META_CLASS_TYPES[code] : nil
      end

      def class_name(lang = :en)
        @directives["CLASS_NAME.#{lang}"]
      end

      def class_definition(lang = :en)
        @directives["CLASS_DEFINITION.#{lang}"]
      end

      def class_note(lang = :en)
        @directives["CLASS_NOTE.#{lang}"]
      end

      def source_language
        @directives["SOURCE_LANGUAGE"]
      end

      def default_supplier
        @directives["DEFAULT_SUPPLIER"]
      end

      def default_version
        @directives["DEFAULT_VERSION"]
      end

      def each(&block)
        @directives.each(&block)
      end
    end
  end
end
