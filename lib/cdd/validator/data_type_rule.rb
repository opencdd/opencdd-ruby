# frozen_string_literal: true

module Cdd
  module Validator
    class DataTypeRule < Rule
      def id
        "R12"
      end

      def applies?(context)
        context.column_iri == Cdd::PropertyIds::MDC_P022
      end

      def call(value, _context)
        return true if value.nil? || value.to_s.strip.empty?
        !Cdd::DataType.parse(value.to_s).nil?
      rescue ArgumentError
        false
      end

      def message(value, _context)
        "R12: data type expression #{value.inspect} is not well-formed"
      end
    end
  end
end
