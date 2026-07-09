# frozen_string_literal: true

require "strscan"

module Cdd
  module ParseHelpers
    module_function

    def parse_irdi_list(raw)
      return [] if raw.nil? || raw.to_s.strip.empty?
      unwrap_delimiters(raw.to_s.strip)
        .split(/[,\s]+/)
        .filter_map { |t| Cdd::IRDI.parse(t) }
    end

    def parse_pair_list(raw)
      return [] if raw.nil? || raw.to_s.strip.empty?
      s = raw.to_s.strip
      return parse_synonym_tuples(s) if brace_wrapped?(s)
      return [[nil, s]] unless paren_wrapped?(s)
      unwrap_parens(s)
        .split(",")
        .each_slice(2)
        .map { |lang, name| [lang&.strip, name&.strip] }
    end

    def parse_synonym_tuples(raw)
      return [] if raw.nil? || raw.to_s.strip.empty?
      SynonymTupleScanner.new(raw.to_s).scan
    end

    def parse_string_list(raw)
      return [] if raw.nil? || raw.to_s.strip.empty?
      unwrap_delimiters(raw.to_s.strip)
        .split(",")
        .map(&:strip)
        .reject(&:empty?)
    end

    def unwrap_parens(s)
      paren_wrapped?(s) ? s[1..-2] : s
    end

    def unwrap_delimiters(s)
      return s[1..-2] if paren_wrapped?(s) || brace_wrapped?(s)
      s
    end

    def paren_wrapped?(s)
      s.start_with?("(") && s.end_with?(")")
    end

    def brace_wrapped?(s)
      s.start_with?("{") && s.end_with?("}")
    end
  end

  class SynonymTupleScanner
    def initialize(source)
      @ss = StringScanner.new(source)
    end

    def scan
      @ss.skip(/\s*\{?\s*/)
      collect_tuples
    end

    private

    def collect_tuples
      result = []
      while @ss.check(/\(/)
        result << scan_tuple
        @ss.skip(/\s*,\s*/)
      end
      result
    end

    def scan_tuple
      @ss.skip(/\(\s*/)
      name = scan_element_until(",")
      @ss.skip(/,\s*/)
      lang = scan_element_until(")")
      @ss.skip(/\)/)
      [lang&.strip, name&.strip]
    end

    def scan_element_until(delimiter)
      start = @ss.pos
      until @ss.eos?
        ch = @ss.peek(1)
        return @ss.string[start...@ss.pos] if ch == delimiter || ch == ")"
        @ss.getch
      end
      @ss.string[start...@ss.pos]
    end
  end
end
