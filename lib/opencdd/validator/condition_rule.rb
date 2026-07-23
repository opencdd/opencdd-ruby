# frozen_string_literal: true

module Opencdd
  module Validator
    class ConditionRule < Rule
      def id
        "R11"
      end

      def applies?(context)
        context.column_iri == Opencdd::PropertyIds::MDC_P028 ||
          context.value_kind == :condition
      end

      def call(value, _context)
        return true if value.nil? || value.to_s.strip.empty?
        # parse returns a boolean Condition or a Condition::ClassReference
        # for bare-IRDI / bare-set conditions (IEC 62683 shape). Both are
        # valid; only malformed input raises ArgumentError.
        !Opencdd::Condition.parse(value.to_s).nil?
      rescue ArgumentError
        false
      end

      def message(value, _context)
        "R11: condition expression #{value.inspect} is not well-formed"
      end
    end
  end
end
