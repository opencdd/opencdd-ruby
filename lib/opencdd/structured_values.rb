# frozen_string_literal: true

module Opencdd
  # Single source of truth for parsing/serialising CDD's structured
  # property-value wire forms: reference sets, synonym tuples,
  # class references, data types.
  #
  # Every format reader, writer, validator, and exporter that touches
  # a `{a,b,c}` or `(a,b)` collection goes through this module.
  # The brace/paren/comma convention lives here exactly once; a bug
  # fixed here is fixed everywhere.
  module StructuredValues
    module_function

    # ── Generic collection seam ─────────────────────────────────
    #
    # Used by Database#normalize_reference_collections!,
    # Database#rewrite_back_references!, Cddal::Builder,
    # Cddal::Serializer, Validator::ReferenceRule,
    # Validator::ClassReferenceRule. Replaces six hand-rolled
    # variants of "strip delimiters, split, reject empties".

    # Split a `{a,b,c}` or `(a,b,c)` literal into `[a, b, c]`.
    # Accepts unwrapped strings too (split directly). Empty/blank
    # input returns []. Respects nested `{}`/`()` so
    # `{(a,b),(c,d)}` yields two tuple strings, not four fragments.
    def unwrap_and_split(value)
      return [] if value.nil? || value.to_s.strip.empty?
      s = value.to_s.strip
      s = s[1..-2] if (s.start_with?("{") && s.end_with?("}")) ||
                       (s.start_with?("(") && s.end_with?(")"))
      split_at_top_level_commas(s)
    end

    # Inverse of +unwrap_and_split+: join with `,` and wrap in `{}`.
    # Empty input returns "".
    def rejoin(elements)
      elements = Array(elements).map(&:to_s).reject { |e| e.nil? || e.strip.empty? }
      return "" if elements.empty?
      "{#{elements.join(",")}}"
    end

    def parse_synonyms(value)
      return [] if value.nil? || value.to_s.strip.empty?
      SynonymTupleScanner.new(value.to_s).scan
    end

    def serialize_synonyms(pairs)
      return "" if pairs.nil? || pairs.empty?
      tuples = Array(pairs).map do |pair|
        lang, name = Array(pair)
        "(#{name},#{lang})"
      end
      "{#{tuples.join(",")}}"
    end

    def parse_ref_set(value)
      return [] if value.nil? || value.to_s.strip.empty?
      unwrap_and_split(value).filter_map { |t| Opencdd::IRDI.parse(t) }
    end

    def serialize_ref_set(irdis)
      return "" if irdis.nil? || irdis.empty?
      elements = Array(irdis).map { |i| i.is_a?(Opencdd::IRDI) ? i.to_s : i.to_s }
      "{#{elements.join(",")}}"
    end

    def parse_class_ref(value)
      return nil if value.nil? || value.to_s.strip.empty?
      Opencdd::IRDI.parse(value.to_s.strip)
    end

    def serialize_class_ref(irdi)
      return "" if irdi.nil?
      irdi.is_a?(Opencdd::IRDI) ? irdi.to_s : irdi.to_s
    end

    def parse_data_type(value)
      return nil if value.nil? || value.to_s.strip.empty?
      Opencdd::DataType.parse_or_string(value)
    end

    # ── Internal: split on commas at the top nesting level only ─
    # Needed so `{(a,b),(c,d)}` → `["(a,b)", "(c,d)"]`, not four
    # fragments.
    def split_at_top_level_commas(s)
      result = []
      current = +""
      depth = 0
      s.each_char do |ch|
        case ch
        when "{", "(" then depth += 1; current << ch
        when "}", ")" then depth -= 1; current << ch
        when ","
          if depth.zero?
            result << current.strip unless current.strip.empty?
            current = +""
          else
            current << ch
          end
        else
          current << ch
        end
      end
      result << current.strip unless current.strip.empty?
      result
    end
    private_class_method :split_at_top_level_commas

    def serialize_data_type(data_type)
      return "" if data_type.nil?
      data_type.to_s
    end

    def parse_condition(value)
      return nil if value.nil? || value.to_s.strip.empty?
      Opencdd::Condition.parse(value)
    rescue ArgumentError
      nil
    end

    def serialize_condition(condition)
      return "" if condition.nil?
      condition.to_s
    end

    def parse_value_format(value)
      return nil if value.nil? || value.to_s.strip.empty?
      Opencdd::ValueFormat.parse(value)
    end

    def serialize_value_format(format)
      return "" if format.nil?
      format.to_s
    end
  end
end

# Internal scanner for the `{(name,lang),(name,lang)}` synonym wire
# form. Lives here so StructuredValues is the single home for all
# collection parsing. Parsed via StringScanner because the format
# can include quoted commas inside names.
class Opencdd::StructuredValues::SynonymTupleScanner
  def initialize(source)
    require "strscan"
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
