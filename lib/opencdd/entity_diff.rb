# frozen_string_literal: true

module Opencdd
  # Compute a structured diff between two entities of the same IRDI.
  #
  # Pure value object: doesn't mutate its inputs, doesn't reach
  # beyond +entity.properties+. Iterates the union of keys and
  # categorizes each into +added+, +removed+, or +changed+.
  #
  # Multilingual fields (<tt>MDC_P001.en</tt>, <tt>MDC_P001.fr</tt>)
  # are diffed as a group keyed by their base property ID. A change
  # in any language counts as one change to the base field.
  #
  # Example:
  #   diff = Opencdd::EntityDiff.between(v001, v002)
  #   diff.added      # => ["MDC_P999"]
  #   diff.removed    # => []
  #   diff.changed    # => [{ field: "preferred_name", from: "X", to: "Y" }]
  #   diff.empty?     # => false
  class EntityDiff
    Change = Struct.new(:field, :from, :to, keyword_init: true)

    attr_reader :from_entity, :to_entity, :added, :removed, :changed

    def self.between(from_entity, to_entity)
      new(from_entity, to_entity)
    end

    def initialize(from_entity, to_entity)
      raise ArgumentError, "EntityDiff requires same IRDI (#{from_entity.irdi} vs #{to_entity.irdi})" unless from_entity.irdi == to_entity.irdi
      @from_entity = from_entity
      @to_entity   = to_entity
      compute_diff
    end

    def empty?
      added.empty? && removed.empty? && changed.empty?
    end

    # Total change count (added + removed + changed).
    def size
      added.size + removed.size + changed.size
    end

    # Wire-format summary suitable for JSON emit or browser diff view.
    def to_h
      {
        irdi: from_entity.irdi.to_s,
        added: added,
        removed: removed,
        changed: changed.map(&:to_h),
      }
    end

    private

    def compute_diff
      @added = []
      @removed = []
      @changed = []
      from_groups = grouped_properties(from_entity)
      to_groups   = grouped_properties(to_entity)
      (from_groups.keys | to_groups.keys).sort.each do |field|
        from_val = from_groups[field]
        to_val   = to_groups[field]
        if from_val.nil? && !to_val.nil?
          @added << field
        elsif !from_val.nil? && to_val.nil?
          @removed << field
        elsif values_differ?(from_val, to_val)
          @changed << Change.new(field: field, from: from_val, to: to_val)
        end
      end
    end

    # Group multilingual keys (<base>.<lang>) under their <base>.
    # Returns +{ base_property_id => grouped_value }+ where
    # +grouped_value+ is a string for monolingual fields or a
    # sorted +{ lang => value }+ hash for multilingual fields.
    def grouped_properties(entity)
      groups = Hash.new { |h, k| h[k] = {} }
      entity.properties.each do |key, value|
        next if value.nil?
        k = key.to_s
        base, lang = split_language_suffix(k)
        if lang
          groups[base][lang] = value.to_s
        else
          groups[base] = value.to_s
        end
      end
      # Collapse empty hashes (a group that had only nil values).
      groups.transform_values { |v| v.is_a?(Hash) && v.empty? ? nil : v }
    end

    def split_language_suffix(key)
      m = key.match(/\A(?<base>.+?)\.(?<lang>[a-z]{2,3}(?:-[a-z0-9]+)?)\z/i)
      return [key, nil] unless m
      [m[:base], m[:lang].downcase]
    end

    def values_differ?(from_val, to_val)
      return from_val != to_val unless from_val.is_a?(Hash) && to_val.is_a?(Hash)
      # For multilingual groups: compare as normalized hashes.
      from_val == to_val ? false : true
    end
  end
end
