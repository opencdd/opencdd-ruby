# frozen_string_literal: true

module Opencdd
  class Database
    # Mutations: rename, merge, apply_change_request, remove,
    # apply_view_control, and back-reference rewriting.
    module Mutations
      REFERENCE_VALUE_KINDS = %i[identifier_ref set_of_refs class_ref].freeze

      def rename_entity(old_code, new_code)
        old_code_s = old_code.to_s
        new_code_s = new_code.to_s
        return self if old_code_s == new_code_s

        target = find_by_code(old_code_s)
        return self unless target

        clash = find_by_code(new_code_s)
        if clash && clash.irdi != target.irdi
          warn "Cannot rename #{old_code_s} → #{new_code_s}: target code already in use by #{clash.irdi}"
          return self
        end

        old_irdi = target.irdi
        new_irdi = old_irdi.with_code(new_code_s)

        @entities_by_irdi.delete(old_irdi)
        @entities_by_code[old_code_s].delete(target)

        ref_property_ids = Opencdd::PropertyIds::REGISTRY.select do |_, e|
          REFERENCE_VALUE_KINDS.include?(e.value_kind)
        end.keys

        entities.each do |entity|
          rewrite_back_references!(entity, old_irdi, new_irdi, ref_property_ids)
        end

        code_pid = target.class.default_code_property_id(target.meta_class_irdi)
        target.replace_code_value!(code_pid, new_code_s)
        target.replace_irdi!(new_irdi)

        @entities_by_irdi[new_irdi] = target
        @entities_by_code[new_code_s] << target

        rebuild_symbol_table!
        self
      end

      def merge(other)
        raise TypeError, "merge expects a Opencdd::Database" unless other.is_a?(Opencdd::Database)
        other.entities.each { |e| add_entity(e) }
        finalize!
        self
      end

      def apply_change_request(cr, removals: [])
        raise TypeError, "apply_change_request expects a Opencdd::Database" unless cr.is_a?(Opencdd::Database)
        cr.entities.each { |e| add_entity(e) }
        Array(removals).each { |r| remove_by_irdi(r) }
        finalize!
        self
      end

      def remove_by_irdi(ref)
        irdi = ref.is_a?(Opencdd::IRDI) ? ref : Opencdd::IRDI.parse(ref.to_s)
        return unless irdi
        remove_entity_by_irdi!(irdi)
        @entity_sources.delete(irdi)
        self
      end

      def apply_view_control(klass, view_control)
        properties = effective_properties.for(klass).to_a
        return properties unless view_control.is_a?(Opencdd::ViewControl)

        controlled = view_control.controlled_class_irdis
        k = coerce_entity(klass)
        return properties unless k.is_a?(Opencdd::Klass) && controlled.include?(k.irdi)

        shown = view_control.shown_property_irdis
        lookup = properties.each_with_object({}) { |p, h| h[p.irdi] = p }
        shown.filter_map { |irdi| lookup[irdi] }
      end

      private

      def rewrite_back_references!(entity, old_irdi, new_irdi, ref_property_ids)
        ref_property_ids.each do |pid|
          raw = entity.properties[pid]
          next if raw.nil?
          entry = Opencdd::PropertyIds::REGISTRY[pid]
          case entry.value_kind
          when :identifier_ref
            parsed = Opencdd::IRDI.parse(raw.to_s)
            next unless parsed == old_irdi
            entity.write_property!(pid, new_irdi.to_s)
          when :set_of_refs
            elements = Opencdd::StructuredValues.unwrap_and_split(raw)
            next if elements.empty?
            mapped = elements.map { |e| e == old_irdi.to_s ? new_irdi.to_s : e }
            entity.write_property!(pid, Opencdd::StructuredValues.rejoin(mapped))
          when :class_ref
            entity.write_property!(pid, substitute_class_ref_value(raw.to_s, old_irdi, new_irdi))
          end
        end
      end

      def substitute_class_ref_value(raw, old_irdi, new_irdi)
        out = raw.sub(old_irdi.to_s, new_irdi.to_s)
        return out if old_irdi.code.nil? || old_irdi.code == new_irdi.code
        out.sub(old_irdi.code, new_irdi.code)
      end

      def remove_entity_by_irdi!(irdi)
        entity = @entities_by_irdi.delete(irdi)
        return unless entity
        if entity.code
          list = @entities_by_code[entity.code]
          list.delete(entity)
          @entities_by_code.delete(entity.code) if list.empty?
        end
        if entity.type
          @entities_by_type[entity.type].delete(entity)
        end
        @symbol_table.delete_if { |_, e| e.equal?(entity) }
      end
    end
  end
end
