# frozen_string_literal: true

module Cdd
  module Validator
    class Rule
      def id
        raise NotImplementedError
      end

      def applies?(context)
        raise NotImplementedError
      end

      def call(value, context)
        raise NotImplementedError
      end

      def message(value, context)
        "#{id}: value #{value.inspect} is invalid"
      end
    end
  end
end
