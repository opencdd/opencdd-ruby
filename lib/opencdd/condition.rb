# frozen_string_literal: true

require "set"

module Opencdd
  class Condition
    SET_PATTERN = /\A\{(?<body>.*)\}\z/m.freeze
    EXPRESSION_PATTERN = /\A
      (?<left>[^=!<>]+?)
      \s*
      (?<op>==|!=)
      \s*
      (?<right>.+)
    \z/x.freeze

    attr_reader :left, :operator, :right

    def initialize(left, operator, right)
      @left = left.to_s.strip
      unless %w[== !=].include?(operator.to_s)
        raise ArgumentError, "unsupported condition operator: #{operator.inspect}"
      end
      @operator = operator.to_s
      @right = right
    end

    def set?
      @right.is_a?(Set)
    end

    def satisfied_by?(bindings)
      hash = bindings.is_a?(Hash) ? bindings : bindings.to_h
      actual = hash[@left] || hash[@left.to_sym]
      return false if actual.nil?

      if set?
        contained = @right.any? { |r| matches?(actual, r) }
        @operator == "==" ? contained : !contained
      else
        equal = matches?(actual, @right)
        @operator == "==" ? equal : !equal
      end
    end

    def to_s
      rhs = if set?
              "{ #{@right.to_a.join(", ")} }"
            elsif quoted_literal?(@right)
              "\"#{@right}\""
            else
              @right.to_s
            end
      "#{@left} #{@operator} #{rhs}"
    end

    alias_method :inspect, :to_s

    def ==(other)
      other.is_a?(Opencdd::Condition) &&
        @left == other.left &&
        @operator == other.operator &&
        normalize_for_eq(@right) == normalize_for_eq(other.right)
    end
    alias_method :eql?, :==

    def hash
      [@left, @operator, normalize_for_eq(@right)].hash
    end

    class << self
      def parse(raw)
        return nil if raw.nil? || raw.to_s.strip.empty?
        s = raw.to_s.strip
        if s =~ EXPRESSION_PATTERN
          left = Regexp.last_match(:left).strip
          op   = Regexp.last_match(:op)
          raw_right = Regexp.last_match(:right).strip
          new(left, op, parse_rhs(raw_right))
        else
          raise ArgumentError, "invalid condition expression: #{s.inspect}"
        end
      end

      private

      def parse_rhs(rhs)
        if rhs =~ SET_PATTERN
          body = Regexp.last_match(:body)
          elements = body.split(/[,\s]+/).map(&:strip).reject(&:empty?)
          Set.new(elements)
        else
          unquote(rhs)
        end
      end

      def unquote(s)
        s = s.strip
        return s[1..-2] if s.start_with?('"') && s.end_with?('"')
        return s[1..-2] if s.start_with?("'") && s.end_with?("'")
        s
      end
    end

    private

    def matches?(actual, expected)
      actual.to_s == expected.to_s
    end

    def quoted_literal?(value)
      s = value.to_s
      (s.start_with?('"') && s.end_with?('"')) ||
        (s.start_with?("'") && s.end_with?("'"))
    end

    def normalize_for_eq(value)
      value.is_a?(Set) ? value.to_a.sort : value
    end
  end
end
