# frozen_string_literal: true

module Opencdd
  class Database
    # Graph queries: find, coerce, powertype API, tree walkers,
    # property/class/value-list lookups, relation queries.
    module Queries
      def resolve_reference(ref)
        return nil if ref.nil?
        return ref if ref.is_a?(Opencdd::Entity)

        key = ref.to_s.strip
        return nil if key.empty?

        if key.include?("/") || key.include?("#")
          irdi = Opencdd::IRDI.parse(key)
          return find(irdi)
        end

        entity = @symbol_table[key]
        return entity if entity

        by_code = find_by_code(key)
        return by_code if by_code

        irdi = Opencdd::IRDI.parse(key)
        irdi ? find(irdi) : nil
      end

      def find(irdi)
        return nil if irdi.nil?
        key = Opencdd::IRDI === irdi ? irdi : Opencdd::IRDI.parse(irdi)
        return nil unless key
        @entities_by_irdi[key]
      end

      def find_by_code(code)
        matches = @entities_by_code[code.to_s]
        return nil if matches.empty?
        matches.first
      end

      def find_all_by_code(code)
        @entities_by_code[code.to_s].dup
      end

      def find_by_name(name, type: nil, lang: :en)
        pools = type ? [@entities_by_type[type]].compact : @entities_by_type.values
        pools.each do |pool|
          hit = pool.find { |e| e.preferred_name(lang).to_s.casecmp(name.to_s).zero? }
          return hit if hit
        end
        nil
      end

      def coerce_entity(value)
        return nil if value.nil?
        return value if value.is_a?(Opencdd::Entity)
        find(value)
      end

      def coerce_irdi(value)
        return nil if value.nil?
        return value.irdi if value.is_a?(Opencdd::Entity)
        return value if value.is_a?(Opencdd::IRDI)
        Opencdd::IRDI.parse(value.to_s)
      end

      def root_classes
        classes.select { |c| c.parent_irdi.nil? }
      end

      # ── Powertype accessors (4-layer ontology) ──────────────

      def categorical_classes
        classes.select(&:powertype?)
      end

      def instances_of(categorical_klass)
        k = coerce_entity(categorical_klass)
        return [] unless k.is_a?(Opencdd::Klass)
        k.categorical_instances(self)
      end

      def valid_class_reference?(categorical_klass, value)
        target = coerce_entity(value)
        return false unless target
        instances_of(categorical_klass).any? { |c| c.irdi == target.irdi }
      end

      # ── Tree walkers ─────────────────────────────────────────

      def class_tree(fields: Opencdd::ClassTree::DEFAULT_FIELDS)
        Opencdd::ClassTree.new(self, fields: fields)
      end

      def effective_properties
        @effective_properties ||= Opencdd::EffectiveProperties.new(self)
      end

      def composition_tree(klass, max_depth: 10)
        Opencdd::CompositionTree.new(self).for(klass, max_depth: max_depth)
      end

      def relation_tree(root = nil, max_depth: 10)
        Opencdd::RelationTree.new(self).for(root, max_depth: max_depth)
      end

      # ── Property / class / value-list lookups ────────────────

      def properties_of(klass)
        k = coerce_entity(klass)
        return [] unless k.is_a?(Opencdd::Klass)
        k.properties_on_class(self)
      end

      def classes_with_property(property)
        irdi = coerce_irdi(property)
        return [] unless irdi
        @class_by_property_irdi&.fetch(irdi, []) || []
      end

      def value_list_of(property)
        prop = coerce_entity(property)
        return nil unless prop.is_a?(Opencdd::Property)

        relations.each do |r|
          next unless r.predication?
          next unless r.domain_irdis.include?(prop.irdi)
          vl = r.codomain_irdi && find(r.codomain_irdi)
          return vl if vl.is_a?(Opencdd::ValueList)
        end

        return nil unless prop.enum?
        identifier = value_list_identifier_of(prop)
        return nil unless identifier
        vl = resolve_reference(identifier)
        vl if vl.is_a?(Opencdd::ValueList)
      end

      def value_list_identifier_of(property)
        case property.parsed_data_type
        when Opencdd::DataType::EnumStringType, Opencdd::DataType::EnumReferenceType
          property.parsed_data_type.value_list_identifier
        end
      end

      def terms_of(value_list)
        return [] if value_list.nil?
        value_list.term_irdis.map { |i| find(i) }.compact
      end

      def relations_for(domain: nil, codomain: nil)
        dom = coerce_irdi(domain)
        cod = coerce_irdi(codomain)
        relations.select do |r|
          (dom.nil?  || r.domain_irdis.include?(dom)) &&
            (cod.nil? || r.codomain_irdi == cod)
        end
      end

      def functions_involving(property)
        irdi = coerce_irdi(property)
        return [] unless irdi
        relations.select do |r|
          r.function? && (r.domain_irdis.include?(irdi) || r.codomain_irdi == irdi)
        end
      end
    end
  end
end
