# frozen_string_literal: true

module Opencdd
  module Validator
    class TypeRule < Rule
      SIMPLE_PREDICATES = {
        "BOOLEAN_TYPE"              => ->(v) { %w[true false].include?(v.to_s.downcase.strip) },
        "STRING_TYPE"               => ->(v) { v.is_a?(String) || !v.nil? },
        "TRANSLATABLE_STRING_TYPE"  => ->(v) { v.is_a?(String) || structured_pairs?(v) },
        "IRDI_TYPE"                 => ->(v) { !Opencdd::IRDI.parse(v.to_s).nil? },
        "IRDI_STRING_TYPE"          => ->(v) { !Opencdd::IRDI.parse(v.to_s).nil? },
        "ICID_STRING"               => ->(v) { !Opencdd::IRDI.parse(v.to_s).nil? },
        "ICID_STRING_TYPE"          => ->(v) { !Opencdd::IRDI.parse(v.to_s).nil? },
        "DATE_TYPE"                 => ->(v) { date?(v) },
        "DATE_TIME_TYPE"            => ->(v) { date_time?(v) },
        "DATETIME_TYPE"             => ->(v) { date_time?(v) },
        "REAL_TYPE"                 => ->(v) { real?(v) },
        "INTEGER_TYPE"              => ->(v) { integer?(v) },
        "INT_TYPE"                  => ->(v) { integer?(v) },
        "RATIONAL_TYPE"             => ->(v) { rational?(v) },
      }.freeze

      def id
        "R03"
      end

      def applies?(context)
        !context.data_type.nil?
      end

      def call(value, context)
        return true if value.nil? || value.to_s.strip.empty?
        token = context.data_type.to_s
        return enum_member?(value, context) if token.start_with?("ENUM_")
        predicate = SIMPLE_PREDICATES[token]
        return true if predicate.nil?
        predicate.call(value) ? true : false
      end

      def message(value, context)
        "R03: value #{value.inspect} does not satisfy data type #{context.data_type}"
      end

      def self.structured_pairs?(value)
        s = value.to_s.strip
        s.start_with?("{") || s.start_with?("(")
      end

      def self.date?(value)
        !!begin
          Date.iso8601(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end
      end

      def self.date_time?(value)
        !!begin
          Time.iso8601(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end
      end

      def self.real?(value)
        !!begin
          Float(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end
      end

      def self.integer?(value)
        !!begin
          Integer(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end
      end

      def self.rational?(value)
        !!begin
          Rational(value.to_s)
        rescue ArgumentError, TypeError, ZeroDivisionError
          nil
        end
      end

      private

      def enum_member?(value, context)
        return true unless context.database
        terms = context.enum_terms_for(context.data_type)
        return true if terms.empty?
        terms.any? { |t| t.to_s == value.to_s }
      end
    end
  end
end

require "time"
require "date"
