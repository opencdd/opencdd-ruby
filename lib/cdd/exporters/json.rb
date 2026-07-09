# frozen_string_literal: true

require "json"

module Cdd
  module Exporters
    class Json < Cdd::Visitor
      attr_reader :nodes

      def initialize
        super
        @nodes = []
      end

      def to_json(database, pretty: true)
        reset!
        @nodes.clear
        visit_database(database)
        pretty ? JSON.pretty_generate(@nodes) : JSON.generate(@nodes)
      end

      def visit_database(database)
        @database = database
        super
      end

      def visit_class(klass)
        @nodes << class_node(klass)
        super
      end

      def visit_property(prop)
        @nodes << property_node(prop)
      end

      def visit_unit(unit)
        @nodes << unit_node(unit)
      end

      def visit_value_list(vl)
        @nodes << value_list_node(vl)
      end

      def visit_value_term(vt)
        @nodes << value_term_node(vt)
      end

      def visit_relation(rel)
        @nodes << relation_node(rel)
      end

      def visit_view_control(vc)
        @nodes << view_control_node(vc)
      end

      private

      # ─────────────────────────────────────────────────────────────
      # Open/closed payload builders
      #
      # Each per-type _node method is a thin wrapper that adds `type:`
      # and any type-specific computed fields (e.g. Property's value_list
      # cross-link). The bulk of every entity's payload comes from
      # `entity_payload`, which iterates the field DSL registry
      # (Cdd::Entity::FieldRegistry.fields_for) — adding a field to
      # the model is a single `field` declaration; no edits here.
      # ─────────────────────────────────────────────────────────────

      def class_node(klass)
        entity_payload(klass).merge(type: "class").compact
      end

      def property_node(prop)
        entity_payload(prop).merge(
          type: "property",
          data_type: prop.parsed_data_type&.to_s,
          value_list: value_list_irdi_of(prop),
        ).compact
      end

      def unit_node(unit)
        entity_payload(unit).merge(type: "unit").compact
      end

      def value_list_node(vl)
        entity_payload(vl).merge(type: "value_list").compact
      end

      def value_term_node(vt)
        entity_payload(vt).merge(type: "value_term").compact
      end

      def relation_node(rel)
        entity_payload(rel).merge(type: "relation").compact
      end

      def view_control_node(vc)
        entity_payload(vc).merge(type: "view_control").compact
      end

      # Iterates every declared field on the entity's class (walking
      # the ancestor chain via FieldRegistry.fields_for). Each field's
      # value is read by name (synthetic fields call their custom
      # reader; pure fields go through FieldReader's typed coercion).
      #
      # Serialization is driven by the field's value_kind so the wire
      # shape stays consistent: IRDI → string, set_of_refs → array of
      # strings, synonym_pairs → array of {lang, name}, etc.
      #
      # Deduplicates by property_id: when two field names alias the
      # same MDC_P### (e.g. source_document and source_document_of_definition),
      # only the first-seen declaration is emitted. Declaration order
      # is base-class first, so the canonical name lives on Entity.
      def entity_payload(entity)
        # Baseline identity fields. Always present (when value is non-nil).
        # These mirror the existing wire shape and are emitted even
        # though they're not DSL field declarations (the model's `irdi`
        # accessor must return the Cdd::IRDI object, not a string).
        payload = {
          irdi: entity.irdi&.to_s,
          code: entity.code,
        }.compact

        seen_property_ids = Set.new

        Cdd::Entity::FieldRegistry.fields_for(entity.class).each do |field|
          next if field.property_id && !seen_property_ids.add?(field.property_id)

          value = entity.public_send(field.name)
          next if value.nil?

          serialized = serialize_value(value, field)
          next if serialized.nil?

          payload[field.wire_name] = serialized
        end
        payload
      end

      def serialize_value(value, field)
        # raw_properties: emit the full hash as-is, no coercion.
        # This preserves every key from the .xls, including
        # multilingual variants and C### workbook-specific codes.
        return value if field.name == :raw_properties && value.is_a?(Hash)

        case field.value_kind
        when :synonym_pairs
          return nil if value.nil?
          value.map { |lang, name| { lang: lang, name: name } }
        when :irdi, :identifier_ref, :class_ref
          return nil if value.nil?
          value.to_s
        when :set_of_refs
          return nil if value.nil?
          value.map { |irdi| irdi.to_s }
        when :string_list
          return nil if value.nil?
          value
        else
          serialize_basic(value)
        end
      end

      def serialize_basic(value)
        case value
        when Cdd::IRDI then value.to_s
        when Array
          # Preserve empty arrays — callers use them as "no entries"
          # signals (e.g. sub_class_selection: [] on a class with no
          # composition children). The payload's final .compact only
          # drops nils, not empties.
          value.map { |v| serialize_basic(v) }
        when Struct
          hash = value.to_h.transform_values { |v| serialize_basic(v) }
          hash.compact!
          hash.empty? ? nil : hash
        when String, Integer, Float, TrueClass, FalseClass, NilClass, Symbol
          value
        else
          # Value objects (Cdd::ClassType, Cdd::Condition,
          # Cdd::ValueFormat, Cdd::PropertyDataTypeElement, etc.)
          # serialize via their canonical to_s. Keeps the wire shape
          # stable without per-type branching here.
          value.to_s
        end
      end

      # Resolves the IRDI of the value list associated with `prop`, if
      # any. Mirrors the cdd.iec.ch property → value-list hyperlink:
      # when a property's data type is an enumeration, its values come
      # from a named value list linked via a predication relation.
      # The Database resolves this at finalize time; we emit the IRDI
      # so the browser can render the cross-link without re-walking
      # the relations.
      def value_list_irdi_of(prop)
        return nil unless @database
        vl = @database.value_list_of(prop)
        vl&.irdi&.to_s
      end
    end
  end
end
