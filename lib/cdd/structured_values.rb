# frozen_string_literal: true

module Cdd
  module StructuredValues
    module_function

    def parse_synonyms(value)
      return [] if value.nil? || value.to_s.strip.empty?
      Cdd::ParseHelpers.parse_synonym_tuples(value.to_s)
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
      s = value.to_s.strip
      s = s[1..-2] if s.start_with?("{") && s.end_with?("}")
      s.split(",").map(&:strip).reject(&:empty?).filter_map do |t|
        Cdd::IRDI.parse(t)
      end
    end

    def serialize_ref_set(irdis)
      return "" if irdis.nil? || irdis.empty?
      elements = Array(irdis).map { |i| i.is_a?(Cdd::IRDI) ? i.to_s : i.to_s }
      "{#{elements.join(",")}}"
    end

    def parse_class_ref(value)
      return nil if value.nil? || value.to_s.strip.empty?
      Cdd::IRDI.parse(value.to_s.strip)
    end

    def serialize_class_ref(irdi)
      return "" if irdi.nil?
      irdi.is_a?(Cdd::IRDI) ? irdi.to_s : irdi.to_s
    end

    def parse_data_type(value)
      return nil if value.nil? || value.to_s.strip.empty?
      Cdd::DataType.parse_or_string(value)
    end

    def serialize_data_type(data_type)
      return "" if data_type.nil?
      data_type.to_s
    end

    def parse_condition(value)
      return nil if value.nil? || value.to_s.strip.empty?
      Cdd::Condition.parse(value)
    rescue ArgumentError
      nil
    end

    def serialize_condition(condition)
      return "" if condition.nil?
      condition.to_s
    end

    def parse_value_format(value)
      return nil if value.nil? || value.to_s.strip.empty?
      Cdd::ValueFormat.parse(value)
    end

    def serialize_value_format(format)
      return "" if format.nil?
      format.to_s
    end
  end
end
