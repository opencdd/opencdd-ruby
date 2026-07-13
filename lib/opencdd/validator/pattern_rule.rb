# frozen_string_literal: true

module Opencdd
  module Validator
    class PatternRule < Rule
      def id
        "R06"
      end

      def applies?(context)
        !context.pattern.nil? && !context.pattern.to_s.strip.empty?
      end

      def call(value, context)
        return true if value.nil? || value.to_s.strip.empty?
        Regexp.new(context.pattern.to_s).match?(value.to_s)
      rescue RegexpError
        false
      end

      def message(value, context)
        "R06: #{value.inspect} does not match pattern #{context.pattern.inspect}"
      end
    end
  end
end
