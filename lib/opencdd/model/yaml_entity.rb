# frozen_string: true

require "lutaml/model"

module Opencdd
  module Model
    # CDD-native YAML entity. Every attribute uses the semantic name
    # from the CDD ontology (preferred_name, superclass, class_type)
    # rather than the IEC 62656-1 wire-format key (MDC_P004, MDC_P010,
    # MDC_P011). Multilingual fields are Hash<String, String>;
    # collection fields are Array<String>.
    #
    # This is the canonical YAML shape for a CDD entity:
    #
    #   ---
    #   irdi: 0112/2///61360_4#AAA001
    #   type: class
    #   code: AAA001
    #   preferred_name:
    #     en: Vehicle
    #     fr: Véhicule
    #   class_type: ITEM_CLASS
    #   superclass: UNIVERSE
    #   applicable_properties:
    #     - vehicle_length
    #     - vehicle_weight
    #
    # Conversion between YamlEntity and the existing Entity model
    # is via #from_entity and #to_entity, which bridge the semantic
    # attributes to the raw properties Hash.
    class YamlEntity < Lutaml::Model::Serializable
      # ── Identity ────────────────────────────────────────────
      attribute :irdi, :string
      attribute :type, :string               # :class, :property, :unit, ...
      attribute :code, :string
      attribute :guid, :string

      # ── Multilingual text (Hash<lang, text>) ───────────────
      attribute :preferred_name, :hash
      attribute :short_name, :hash
      attribute :definition, :hash
      attribute :note, :hash
      attribute :remark, :hash

      # ── Version ─────────────────────────────────────────────
      attribute :version, :string
      attribute :revision, :string

      # ── Class-specific ──────────────────────────────────────
      attribute :class_type, :string          # ITEM_CLASS, CATEGORICAL_CLASS
      attribute :superclass, :string           # IRDI or symbolic name
      attribute :is_case_of, :string, collection: true
      attribute :applicable_properties, :string, collection: true
      attribute :imported_properties, :string, collection: true
      attribute :sub_class_selection, :string, collection: true

      # ── Property-specific ───────────────────────────────────
      attribute :data_type, :string           # REAL_TYPE, CLASS_REFERENCE(X)
      attribute :value_format, :string
      attribute :definition_class, :string    # IRDI or symbolic name
      attribute :unit, :string
      attribute :condition, :string
      attribute :property_data_element_type, :string

      # ── Unit-specific ───────────────────────────────────────
      attribute :unit_structure, :string
      attribute :unit_text, :string

      # ── Value-list-specific ─────────────────────────────────
      attribute :enumerated_values, :string, collection: true
      attribute :list_type, :string

      # ── Relation-specific ───────────────────────────────────
      attribute :relation_type, :string
      attribute :domain, :string, collection: true
      attribute :codomain, :string

      # ── Catch-all for unknown properties (lossless) ────────
      attribute :extra, :hash

      # ── Conversion: Entity → YamlEntity ────────────────────
      def self.from_entity(entity)
        attrs = {
          irdi: entity.irdi&.to_s,
          type: entity.type&.to_s,
          code: entity.code,
          guid: entity[Opencdd::PropertyIds::MDC_P066],
          version: entity[Opencdd::PropertyIds::MDC_P002_1],
          revision: entity[Opencdd::PropertyIds::MDC_P002_2],
        }

        # Multilingual fields
        attrs[:preferred_name] = extract_ml(entity, Opencdd::PropertyIds::MDC_P004)
        attrs[:short_name]     = extract_ml(entity, Opencdd::PropertyIds::MDC_P005)
        attrs[:definition]     = extract_ml(entity, Opencdd::PropertyIds::MDC_P006)
        attrs[:note]           = extract_ml(entity, Opencdd::PropertyIds::MDC_P008)
        attrs[:remark]         = extract_ml(entity, Opencdd::PropertyIds::MDC_P009)

        # Class-specific
        if entity.type == :class
          ct = entity.read_field(:class_type)
          attrs[:class_type] = ct&.to_s
          attrs[:superclass] = entity.read_field(:superclass_irdi)&.to_s
          attrs[:is_case_of] = entity.read_field(:is_case_of_irdis)&.map(&:to_s) || []
          attrs[:applicable_properties] = entity.read_field(:applicable_property_irdis)&.map(&:to_s) || []
          attrs[:imported_properties] = entity.read_field(:imported_property_irdis)&.map(&:to_s) || []
          attrs[:sub_class_selection] = entity.read_field(:sub_class_selection_irdis)&.map(&:to_s) || []
        end

        # Property-specific
        if entity.type == :property
          dt = entity.read_field(:parsed_data_type)
          attrs[:data_type] = dt&.to_s
          attrs[:value_format] = entity.read_field(:parsed_value_format)&.to_s
          dc = entity.read_field(:definition_class_irdi)
          attrs[:definition_class] = dc&.to_s
          ui = entity.read_field(:unit_irdi)
          attrs[:unit] = ui&.to_s
          attrs[:condition] = entity.read_field(:condition)&.to_s
          attrs[:property_data_element_type] = entity.read_field(:property_data_element_type)&.to_s
        end

        new(**attrs.compact)
      end

      # ── Conversion: YamlEntity → Entity ────────────────────
      def to_entity(database = nil)
        props = {}

        props[Opencdd::PropertyIds::MDC_P066] = guid if guid
        props[Opencdd::PropertyIds::MDC_P002_1] = version if version
        props[Opencdd::PropertyIds::MDC_P002_2] = revision if revision

        # Multilingual
        merge_ml_into(props, Opencdd::PropertyIds::MDC_P004, preferred_name)
        merge_ml_into(props, Opencdd::PropertyIds::MDC_P005, short_name)
        merge_ml_into(props, Opencdd::PropertyIds::MDC_P006, definition)
        merge_ml_into(props, Opencdd::PropertyIds::MDC_P008, note)
        merge_ml_into(props, Opencdd::PropertyIds::MDC_P009, remark)

        # Class-specific
        props[Opencdd::PropertyIds::MDC_P011] = class_type if class_type
        props[Opencdd::PropertyIds::MDC_P010] = superclass if superclass
        props[Opencdd::PropertyIds::MDC_P013] = "{#{is_case_of.join(",")}}" if is_case_of&.any?
        props[Opencdd::PropertyIds::MDC_P014] = "{#{applicable_properties.join(",")}}" if applicable_properties&.any?
        props[Opencdd::PropertyIds::MDC_P090] = "{#{imported_properties.join(",")}}" if imported_properties&.any?
        props[Opencdd::PropertyIds::MDC_P016] = "{#{sub_class_selection.join(",")}}" if sub_class_selection&.any?

        # Property-specific
        props[Opencdd::PropertyIds::MDC_P022] = data_type if data_type
        props[Opencdd::PropertyIds::MDC_P024] = value_format if value_format
        props[Opencdd::PropertyIds::MDC_P021] = definition_class if definition_class
        props[Opencdd::PropertyIds::MDC_P041] = unit if unit
        props[Opencdd::PropertyIds::MDC_P028] = condition if condition
        props[Opencdd::PropertyIds::MDC_P020] = property_data_element_type if property_data_element_type

        # Determine entity class from type
        entity_class = Opencdd::MetaClasses.entity_class_for_type(type&.to_sym) || Opencdd::Klass
        meta_code = Opencdd::MetaClasses.meta_class_for_type(type&.to_sym) || "MDC_C002"

        parsed_irdi = irdi ? Opencdd::IRDI.parse(irdi) : nil
        parsed_meta = Opencdd::IRDI.parse(meta_code)

        entity_class.new(
          irdi: parsed_irdi,
          properties: props,
          meta_class_irdi: parsed_meta,
        )
      end

      # ── Helpers ─────────────────────────────────────────────

      def self.extract_ml(entity, pid)
        result = {}
        entity.properties.each do |key, val|
          next unless key.to_s.start_with?("#{pid}.")
          lang = key.to_s.split(".", 2).last
          result[lang] = val if val
        end
        result.empty? ? nil : result
      end
      private_class_method :extract_ml

      def self.merge_ml(props, pid, hash)
        return unless hash&.any?
        hash.each { |lang, val| props["#{pid}.#{lang}"] = val }
      end

      private

      def merge_ml_into(props, pid, hash)
        self.class.merge_ml(props, pid, hash)
      end
    end
  end
end
