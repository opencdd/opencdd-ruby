# frozen_string_literal: true

module Opencdd
  module Validator
    class MandatoryRule < Rule
      def id
        "R07"
      end

      def applies?(context)
        context.requirement_mandatory?
      end

      def call(value, _context)
        return false if value.nil?
        return false if value.to_s.strip.empty?
        true
      end

      def message(_value, context)
        "R07: mandatory column #{context.column_iri} is empty"
      end
    end
  end
end
