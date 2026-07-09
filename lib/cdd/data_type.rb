# frozen_string_literal: true

module Cdd
  class DataType
    SIMPLE = %w[
      STRING_TYPE TRANSLATABLE_STRING_TYPE REAL_TYPE INTEGER_TYPE INT_TYPE
      BOOLEAN_TYPE DATE_TYPE DATE_TIME_TYPE DATETIME_TYPE TIME_TYPE
      IRDI_TYPE ICID_STRING ICID_STRING_TYPE URL_TYPE MIME_TYPE FILE_TYPE
      COMPLEX_TYPE
    ].freeze

    MEASURE = %w[REAL_MEASURE_TYPE INTEGER_MEASURE_TYPE INT_MEASURE_TYPE].freeze

    PARAMETERIZED = %w[CLASS_REFERENCE ENUM_STRING_TYPE ENUM_REFERENCE_TYPE].freeze

    attr_reader :kind

    def initialize(kind)
      @kind = kind.to_s
    end

    def simple?    = SIMPLE.include?(@kind)
    def measure?   = MEASURE.include?(@kind)
    def reference? = is_a?(Cdd::DataType::ClassReference) ||
                     is_a?(Cdd::DataType::EnumStringType) ||
                     is_a?(Cdd::DataType::EnumReferenceType)

    def parameterized? = PARAMETERIZED.include?(@kind)

    def class_reference? = false
    def enum?            = false

    def ==(other)
      other.is_a?(Cdd::DataType) && to_s == other.to_s
    end
    alias_method :eql?, :==

    def hash
      to_s.hash
    end

    def to_s
      @kind
    end

    alias_method :inspect, :to_s

    class RealMeasureType < DataType
      def initialize
        super("REAL_MEASURE_TYPE")
      end
    end

    class IntegerMeasureType < DataType
      def initialize
        super("INTEGER_MEASURE_TYPE")
      end
    end

    class ClassReference < DataType
      attr_reader :class_identifier

      def initialize(class_identifier)
        super("CLASS_REFERENCE")
        @class_identifier = class_identifier.to_s
      end

      def class_reference? = true

      def to_s
        "CLASS_REFERENCE(#{@class_identifier})"
      end
    end

    class EnumStringType < DataType
      attr_reader :value_list_identifier

      def initialize(value_list_identifier)
        super("ENUM_STRING_TYPE")
        @value_list_identifier = value_list_identifier.to_s
      end

      def enum? = true

      def to_s
        "ENUM_STRING_TYPE(#{@value_list_identifier})"
      end
    end

    class EnumReferenceType < DataType
      attr_reader :value_list_identifier

      def initialize(value_list_identifier)
        super("ENUM_REFERENCE_TYPE")
        @value_list_identifier = value_list_identifier.to_s
      end

      def enum? = true

      def to_s
        "ENUM_REFERENCE_TYPE(#{@value_list_identifier})"
      end
    end

    class << self
      def parse(raw)
        return nil if raw.nil? || raw.to_s.strip.empty?
        s = raw.to_s.strip

        if s =~ /\ACLASS_REFERENCE\s*\(\s*(.+?)\s*\)\z/
          return ClassReference.new(Regexp.last_match(1))
        end
        if s =~ /\AENUM_STRING_TYPE\s*\(\s*(.+?)\s*\)\z/
          return EnumStringType.new(Regexp.last_match(1))
        end
        if s =~ /\AENUM_REFERENCE_TYPE\s*\(\s*(.+?)\s*\)\z/
          return EnumReferenceType.new(Regexp.last_match(1))
        end

        case s
        when "REAL_MEASURE_TYPE", "REAL_MEASURE"
          RealMeasureType.new
        when "INTEGER_MEASURE_TYPE", "INT_MEASURE_TYPE", "INTEGER_MEASURE", "INT_MEASURE"
          IntegerMeasureType.new
        when *SIMPLE
          new(s)
        else
          raise ArgumentError, "unknown data_type: #{s.inspect}"
        end
      end

      def parse_or_string(raw)
        parse(raw)
      rescue ArgumentError
        raw.to_s
      end
    end
  end
end
