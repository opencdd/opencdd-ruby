# frozen_string_literal: true

module Cdd
  class InstanceRule
    Group     = Struct.new(:name, :values_by_property, keyword_init: true)
    Exception = Struct.new(:group_name, :line_id, keyword_init: true)

    attr_reader :klass, :groups, :exceptions

    def initialize(klass:, groups:, exceptions: [])
      @klass = klass
      @groups = groups
      @exceptions = exceptions
      freeze
    end

    def expand
      return [] if @groups.empty?

      per_group = @groups.map { |g| expand_group(g) }
      return [] if per_group.any?(&:empty?)

      product = per_group.reduce do |acc, rows|
        acc.product(rows).map { |a, b| a.merge(b) }
      end

      product.reject { |row| exception_match?(row) }
              .map { |row| strip_internal(row) }
    end

    private

    def expand_group(group)
      values = group.values_by_property.transform_values do |list|
        Array(list)
      end
      return [] if values.empty?

      property_ids = values.keys
      length = values.values.map(&:length).max || 0
      length.times.map do |i|
        row = {}
        property_ids.each do |pid|
          v = values[pid][i]
          row[pid] = v unless v.nil?
        end
        row["__line_id__"] = "LINE#{i + 1}"
        row["__group_name__"] = group.name
        row
      end
    end

    def exception_match?(row)
      return false if @exceptions.empty?
      group_name = row["__group_name__"]
      line_id    = row["__line_id__"]
      @exceptions.any? do |ex|
        ex.group_name == group_name && ex.line_id == line_id
      end
    end

    def strip_internal(row)
      out = row.dup
      out.delete("__line_id__")
      out.delete("__group_name__")
      out.delete("__group_indices__")
      out
    end
  end
end
