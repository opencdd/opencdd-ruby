# frozen_string_literal: true

module Opencdd
  class PropertyDataTypeElement
    VALUES = %w[NON_DEPENDENT_P_DET CONDITION_DET DEPENDENT_P_DET].freeze

    attr_reader :value

    def initialize(value)
      v = value.to_s.strip.upcase
      raise ArgumentError, "unknown property data element type: #{value.inspect}" unless VALUES.include?(v)
      @value = v
    end

    def non_dependent? = @value == "NON_DEPENDENT_P_DET"
    def condition?      = @value == "CONDITION_DET"
    def dependent?      = @value == "DEPENDENT_P_DET"

    def conditional?
      condition? || dependent?
    end

    def to_s   = @value
    def to_sym = @value.downcase.to_sym

    def ==(other)
      other.is_a?(Opencdd::PropertyDataTypeElement) && @value == other.value
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
  end
end
