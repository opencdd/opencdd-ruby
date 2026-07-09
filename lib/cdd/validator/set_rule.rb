# frozen_string_literal: true

module Cdd
  module Validator
    class SetRule < Rule
      def id
        "R09"
      end

      def applies?(context)
        context.value_kind == :set_of_refs
      end

      def call(value, _context)
        return true if value.nil? || value.to_s.strip.empty?
        s = value.to_s.strip
        return false unless s.start_with?("{") && s.end_with?("}")
        body = s[1..-2]
        balanced?(body)
      end

      def message(value, _context)
        "R09: set literal #{value.inspect} is not well-formed"
      end

      private

      def balanced?(body)
        depth = 0
        body.each_char do |ch|
          case ch
          when "(" then depth += 1
          when ")" then depth -= 1
          end
          return false if depth.negative?
        end
        depth.zero?
      end
    end
  end
end
