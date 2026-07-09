# frozen_string_literal: true

module Cdd
  class RelationType
    VALUES = %w[
      PREDICATION FUNCTION ASSOCIATION AGGREGATION COMPOSITION
      GENERALIZATION SPECIALIZATION
    ].freeze

    attr_reader :value

    def initialize(value)
      v = value.to_s.strip.upcase
      raise ArgumentError, "unknown relation type: #{value.inspect}" unless VALUES.include?(v)
      @value = v
    end

    def predication?    = @value == "PREDICATION"
    def function?       = @value == "FUNCTION"
    def association?    = @value == "ASSOCIATION"
    def aggregation?    = @value == "AGGREGATION"
    def composition?    = @value == "COMPOSITION"
    def generalization? = @value == "GENERALIZATION"
    def specialization? = @value == "SPECIALIZATION"

    def hierarchical?
      generalization? || specialization? || aggregation? || composition?
    end

    def to_s   = @value
    def to_sym = @value.downcase.to_sym

    def ==(other)
      other.is_a?(Cdd::RelationType) && @value == other.value
    end
    alias_method :eql?, :==

    def hash
      @value.hash
    end

    alias_method :inspect, :to_s

    def self.parse(raw)
      return nil if raw.nil? || raw.to_s.strip.empty?
      s = raw.to_s.strip.upcase
      return nil unless VALUES.include?(s)
      new(s)
    end

    def self.parse_or_symbol(raw)
      parsed = parse(raw)
      return parsed if parsed
      return nil if raw.nil? || raw.to_s.strip.empty?
      raw.to_s.strip.upcase.to_sym
    end
  end
end
