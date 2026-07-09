# frozen_string_literal: true

module Cdd
  module Validator
    class ConditionRule < Rule
      def id
        "R11"
      end

      def applies?(context)
        context.column_iri == Cdd::PropertyIds::MDC_P028 ||
          context.value_kind == :condition
      end

      def call(value, _context)
        return true if value.nil? || value.to_s.strip.empty?
        !Cdd::Condition.parse(value.to_s).nil?
      rescue ArgumentError
        false
      end

      def message(value, _context)
        "R11: condition expression #{value.inspect} is not well-formed"
      end
    end
  end
end
