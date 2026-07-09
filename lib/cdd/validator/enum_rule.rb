# frozen_string_literal: true

module Cdd
  module Validator
    class EnumRule < Rule
      def id
        "R04"
      end

      def applies?(context)
        return false unless context.data_type
        context.data_type.to_s.start_with?("ENUM_")
      end

      def call(value, context)
        return true if value.nil? || value.to_s.strip.empty?
        terms = context.enum_terms_for(context.data_type)
        return true if terms.empty?
        terms.any? { |t| t.to_s == value.to_s }
      end

      def message(value, _context)
        "R04: #{value.inspect} is not a member of the value list"
      end
    end
  end
end
