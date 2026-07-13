# frozen_string_literal: true

module Opencdd
  class ValueFormat
    CODES = %w[NR1 NR2 NR3 M].freeze

    attr_reader :code, :signed, :total, :fractional

    def initialize(code:, signed: false, total: nil, fractional: nil)
      unless CODES.include?(code.to_s)
        raise ArgumentError, "unknown value_format code: #{code.inspect}"
      end
      @code = code.to_s
      @signed = signed
      @total = total
      @fractional = fractional
    end

    def numeric? = @code != "M"
    def string?  = @code == "M"

    def to_s
      if @code == "M"
        @total ? "M..#{@total}" : "M"
      else
        sign = @signed ? "S" : ""
        frac = @fractional ? ".#{@fractional}" : ""
        total_part = @total ? "..#{@total}" : ""
        "#{@code} #{sign}#{total_part}#{frac}".strip
      end
    end

    alias_method :inspect, :to_s

    def ==(other)
      other.is_a?(Opencdd::ValueFormat) &&
        @code == other.code &&
        @signed == other.signed &&
        @total == other.total &&
        @fractional == other.fractional
    end
    alias_method :eql?, :==

    def hash
      [@code, @signed, @total, @fractional].hash
    end

    PATTERN = /\A
      (?<code>NR1|NR2|NR3|M)
      (?:
        \s*(?<signed>S)?
        \.\.(?<total>\d+)
        (?:\.(?<frac>\d+))?
      )?
    \z/x.freeze

    class << self
      def parse(raw)
        return nil if raw.nil? || raw.to_s.strip.empty?
        s = raw.to_s.strip
        match = s.match(PATTERN)
        return nil unless match
        code = match[:code]
        signed = !match[:signed].nil?
        total = match[:total]&.to_i
        fractional = match[:frac]&.to_i
        new(code: code, signed: signed, total: total, fractional: fractional)
      end
    end
  end
end
