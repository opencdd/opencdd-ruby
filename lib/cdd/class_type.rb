# frozen_string_literal: true

module Cdd
  class ClassType
    VALUES = %w[ITEM_CLASS CATEGORICAL_CLASS VALUE_CLASS MESSAGE_CLASS].freeze

    attr_reader :value

    def initialize(value)
      raise ArgumentError, "unknown class_type: #{value}" unless VALUES.include?(value.to_s)
      @value = value.to_s
    end

    def item?         = @value == "ITEM_CLASS"
    def categorical?  = @value == "CATEGORICAL_CLASS"
    def value_class?  = @value == "VALUE_CLASS"
    def message?      = @value == "MESSAGE_CLASS"

    def to_s   = @value
    def to_sym = @value.downcase.to_sym

    def self.parse(raw)
      return nil if raw.nil? || raw.to_s.strip.empty?
      s = raw.to_s.strip.upcase
      return nil unless VALUES.include?(s)
      new(s)
    end

    VALUES.each do |v|
      define_method("#{v.downcase}?") { @value == v }
    end
  end
end
