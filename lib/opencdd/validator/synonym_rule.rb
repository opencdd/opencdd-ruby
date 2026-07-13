# frozen_string_literal: true

module Opencdd
  module Validator
    class SynonymRule < Rule
      def id
        "R10"
      end

      def applies?(context)
        context.column_iri == Opencdd::PropertyIds::MDC_P004_2 ||
          context.column_iri == Opencdd::PropertyIds::MDC_P007
      end

      def call(value, _context)
        return true if value.nil? || value.to_s.strip.empty?
        s = value.to_s.strip
        return false unless s.start_with?("{") && s.end_with?("}")
        body = s[1..-2].strip
        return true if body.empty?
        tuples = body.split(/\)\s*,\s*/).map(&:strip)
        tuples.all? { |t| t.start_with?("(") }
      end

      def message(value, _context)
        "R10: synonymous-name literal #{value.inspect} is not well-formed"
      end
    end
  end
end
