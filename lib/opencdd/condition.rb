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

    # A single bare token (IRDI or short code) without internal whitespace.
    # Used to detect class-reference conditions of the form
    # `0112/2///62683#ACE132` and distinguish them from malformed input
    # like "no operator here" (which has internal whitespace).
    SINGLE_TOKEN_PATTERN = /\A\S+\z/.freeze

    attr_reader :left, :operator, :right

    def initialize(left, operator, right)
      @left = left.to_s.strip
      unless %w[== !=].include?(operator.to_s)
        raise ArgumentError, "unsupported condition operator: #{operator.inspect}"
      end
      @operator = operator.to_s
      @right = right
    end

    def class_reference?
      false
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
        elsif s =~ SET_PATTERN
          body = Regexp.last_match(:body)
          elements = body.split(/[,\s]+/).map(&:strip).reject(&:empty?)
          ClassReference.new(irdis: elements)
        elsif SINGLE_TOKEN_PATTERN.match?(s)
          ClassReference.new(irdis: [s])
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

    # A condition of the form `{0112/2///62683#ACE132}` or a bare
    # `0112/2///62683#ACE132` — meaning "this property applies when the
    # host class is one of the listed IRDIs". IEC 62683 stores property
    # conditions this way; the regular boolean-expression grammar in
    # +Condition+ cannot represent it.
    class ClassReference < Condition
      attr_reader :irdis

      # The binding key (string or symbol) consulted by +#satisfied_by?+
      # to discover the host class IRDI. Callers that resolve the host
      # class via a different key should override +satisfied_by?+.
      HOST_CLASS_KEYS = [:class, :host_class, "class", "host_class"].freeze

      def initialize(irdis:)
        @irdis = Array(irdis).map(&:to_s)
        @left = nil
        @operator = nil
        @right = nil
      end

      def class_reference?
        true
      end

      def set?
        @irdis.size > 1
      end

      def satisfied_by?(bindings)
        hash = bindings.is_a?(Hash) ? bindings : bindings.to_h
        actual = HOST_CLASS_KEYS.map { |k| hash[k] }.compact.first
        return true if actual.nil?
        @irdis.any? { |irdi| actual.to_s == irdi }
      end

      def to_s
        @irdis.size == 1 ? @irdis.first : "{#{@irdis.join(', ')}}"
      end

      def ==(other)
        other.is_a?(ClassReference) && Set.new(@irdis) == Set.new(other.irdis)
      end
      alias_method :eql?, :==

      def hash
        Set.new(@irdis).hash
      end
    end
  end
end
