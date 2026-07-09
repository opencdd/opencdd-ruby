# frozen_string_literal: true

module Cdd
  module Validator
    class FormatRule < Rule
      TOKEN_PATTERN = %r{
        \A
        (?<type>NR1|NR2|NR3|M|B|Date|DT|Bool)
        (?:\s+(?<sign>S|U))?
        (?:\.\.(?<width>\d+))?
        (?:\.(?<decimals>\d+))?
        \z
      }x.freeze

      def id
        "R05"
      end

      def applies?(context)
        !context.value_format.nil? && !context.value_format.to_s.strip.empty?
      end

      def call(value, context)
        return true if value.nil? || value.to_s.strip.empty?
        match = TOKEN_PATTERN.match(context.value_format.to_s.strip)
        return false unless match
        type_check(value, match)
      end

      def message(value, context)
        "R05: #{value.inspect} does not match value format #{context.value_format}"
      end

      private

      def type_check(value, match)
        width = match[:width]
        case match[:type]
        when "NR1" then !!(Integer(value.to_s) rescue nil)
        when "NR2", "NR3" then !!(Float(value.to_s) rescue nil)
        when "M" then value.to_s.length <= (width || "255").to_i
        when "B" then value.to_s.match?(/\A[01]+\z/) && value.to_s.length <= (width || "8").to_i
        when "Date" then !!(Date.iso8601(value.to_s) rescue nil)
        when "DT" then !!(Time.iso8601(value.to_s) rescue nil)
        when "Bool" then %w[true false].include?(value.to_s.downcase)
        else false
        end
      end
    end
  end
end

require "date"
require "time"
