# frozen_string_literal: true

module Opencdd
  class Database
    # Finalization: link class hierarchy, property↔class links,
    # value-list links, normalize reference collections, rebuild
    # the symbol table.
    module Finalization
      def finalize!
        normalize_reference_collections!
        link_class_hierarchy!
        link_property_classes!
        link_value_lists!
        rebuild_symbol_table!
        self
      end

      def normalize_reference_collections!
        each_reference_collection do |entity, pid, _raw, elements|
          entity.write_property!(pid, Opencdd::StructuredValues.rejoin(elements))
        end
        self
      end

      def each_reference_collection
        return enum_for(:each_reference_collection) unless block_given?
        set_property_ids = Opencdd::PropertyIds::REGISTRY
                             .select { |_, e| e.value_kind == :set_of_refs }
                             .keys
        entities.each do |entity|
          set_property_ids.each do |pid|
            raw = entity.properties[pid]
            next if raw.nil? || raw.to_s.strip.empty?
            elements = Opencdd::StructuredValues.unwrap_and_split(raw)
            next if elements.empty?
            yield(entity, pid, raw, elements)
          end
        end
      end

      def rebuild_symbol_table!
        entities.each { |e| register_entity_symbols(e) }
      end

      private

      def link_class_hierarchy!
        classes.each do |klass|
          next if klass.parent_irdi
          parent_id = klass.parent_property_id || Opencdd::PropertyIds::MDC_P010
          parent_raw = klass.properties[parent_id]
          next if parent_raw.nil? || parent_raw.to_s.strip.empty?
          target = resolve_reference(parent_raw)
          next unless target
          next unless target.is_a?(Opencdd::Klass)
          klass.attach_parent_irdi(target.irdi)
          target.add_child(klass)
        end
      end

      def link_property_classes!
        @class_by_property_irdi = Hash.new { |h, k| h[k] = [] }
        link_property_classes_via_relations!
        link_property_classes_via_definition_class!
      end

      def link_property_classes_via_relations!
        relations.each do |r|
          next unless r.predication? || r.function?
          next if r.domain_irdis.empty?
          next unless r.codomain_irdi
          r.domain_irdis.each do |d|
            next unless d
            src = find(d)
            dst = find(r.codomain_irdi)
            next unless src && dst

            if src.is_a?(Opencdd::Klass) && dst.is_a?(Opencdd::Property)
              src.declare_property(dst.irdi)
              @class_by_property_irdi[dst.irdi] << src unless @class_by_property_irdi[dst.irdi].include?(src)
            elsif src.is_a?(Opencdd::Property) && dst.is_a?(Opencdd::Klass)
              dst.declare_property(src.irdi)
              @class_by_property_irdi[src.irdi] << dst unless @class_by_property_irdi[src.irdi].include?(dst)
            end
          end
        end
      end

      def link_property_classes_via_definition_class!
        properties.each do |prop|
          dc_raw = prop.properties[Opencdd::PropertyIds::MDC_P021]
          next unless dc_raw
          target = resolve_reference(dc_raw)
          next unless target.is_a?(Opencdd::Klass)
          target.declare_property(prop.irdi)
          @class_by_property_irdi[prop.irdi] << target unless @class_by_property_irdi[prop.irdi].include?(target)
        end
      end

      def link_value_lists!
        properties.each do |prop|
          next unless prop.enum?
          identifier = value_list_identifier_of(prop)
          vl_irdi = identifier && resolve_reference(identifier)&.irdi
          next unless vl_irdi
          vl = find(vl_irdi)
          next unless vl.is_a?(Opencdd::ValueList)
          @class_by_property_irdi[prop.irdi] << vl unless @class_by_property_irdi[prop.irdi].include?(vl)
        end
      end
    end
  end
end
