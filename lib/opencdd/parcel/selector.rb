# frozen_string_literal: true

module Opencdd
  module Parcel
    # Pure-data value object describing a parcel entity selection.
    #
    # The Selector captures the intent of an export:
    #   - +entities:+ — an Array of IRDIs (or entities) to include.
    #     +nil+ means "every entity in the database".
    #   - +closure:+ — whether to expand the entity set along the
    #     class hierarchy. One of +:none+, +:ancestors+,
    #     +:descendants+, or +:tree+ (both).
    #
    # Resolution against a +Opencdd::Database+ returns a flat
    # +Array<Opencdd::Entity>+ ordered by type (class, property,
    # value_list, value_term, unit, relation, view_control). The
    # caller (Writer, split, etc.) iterates and groups by type.
    #
    # Cross-type lifting (declared properties, value_lists,
    # relations, units) is +Database+'s responsibility; the selector
    # only walks the class hierarchy and asks the database for
    # cross-type dependencies.
    #
    # Example:
    #   sel = Opencdd::Parcel::Selector.new(entities: ["0112/2///61360_4#AAA001"], closure: :tree)
    #   entities = sel.resolve(database)
    #
    Selector = Struct.new(:entities, :closure, keyword_init: true) do
      CLOSURES = %i[none ancestors descendants tree].freeze

      def initialize(entities: nil, closure: :none)
        raise ArgumentError, "invalid closure: #{closure.inspect}" unless CLOSURES.include?(closure)
        super(entities: entities, closure: closure)
      end

      def resolve(database)
        return database.entities.to_a if entities.nil? && closure == :none

        seed = expand_seed(database)
        expanded = apply_closure(database, seed)
        lift_cross_type(database, expanded)
      end

      private

      def expand_seed(database)
        Array(entities).flat_map { |e| resolve_entity(database, e) }
      end

      def resolve_entity(database, candidate)
        case candidate
        when Opencdd::Entity then [candidate]
        when Opencdd::IRDI, String then
          entity = database.find(candidate)
          entity ? [entity] : []
        when nil then []
        else
          raise TypeError, "Selector entities must be Opencdd::Entity, Opencdd::IRDI, or String; got #{candidate.class}"
        end
      end

      def apply_closure(database, seed)
        return seed if closure == :none || seed.empty?
        classes = seed.select { |e| e.is_a?(Opencdd::Klass) }
        return seed if classes.empty?

        out = seed.dup
        if closure == :ancestors || closure == :tree
          classes.each { |k| add_ancestors(out, k) }
        end
        if closure == :descendants || closure == :tree
          classes.each { |k| add_descendants(out, k) }
        end
        out
      end

      def add_ancestors(out, klass)
        klass.ancestors.each do |a|
          out << a unless out.include?(a)
        end
      end

      def add_descendants(out, klass)
        klass.descendants.each do |d|
          out << d unless out.include?(d)
        end
      end

      # Lifts cross-type dependencies for the resolved classes: their
      # declared properties, value_lists those properties reference,
      # units those properties use, and relations where the class is
      # in domain or codomain. This makes the selected parcel
      # self-sufficient when written.
      def lift_cross_type(database, entities)
        out = entities.dup
        classes = entities.select { |e| e.is_a?(Opencdd::Klass) }
        classes.each do |klass|
          database.properties_of(klass).each { |p| out << p unless out.include?(p) }
          database.relations_for(domain: klass.irdi).each { |r| out << r unless out.include?(r) }
          database.relations_for(codomain: klass.irdi).each { |r| out << r unless out.include?(r) }
          database.properties_of(klass).each do |prop|
            next unless prop.is_a?(Opencdd::Property)
            if prop.unit_irdi
              unit = database.find(prop.unit_irdi)
              out << unit if unit.is_a?(Opencdd::Unit) && !out.include?(unit)
            end
            vl = database.value_list_of(prop)
            out << vl if vl && !out.include?(vl)
          end
        end
        out
      end
    end
  end
end
