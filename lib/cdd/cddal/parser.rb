# frozen_string_literal: true

module Cdd
  module Cddal
    class Parser
      def self.parse(source)
        new(Lexer.new(source).tokens).parse
      end

      def initialize(tokens)
        @tokens = tokens
      end

      def parse
        GeneratedParser.new(@tokens).parse
      end
    end
  end
end
