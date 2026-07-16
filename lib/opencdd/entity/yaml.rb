# frozen_string_literal: true

require "lutaml/model"

module Opencdd
  class Entity < Lutaml::Model::Serializable
    # CDD-native YAML serialization model.
    #
    # This is the deepened YAML adapter: the conversion logic that
    # translates between semantic CDD attribute names (preferred_name,
    # superclass, class_type) and IEC 62656-1 wire-format keys
    # (MDC_P004, MDC_P010, MDC_P011) lives here, inside Entity's
    # namespace. Entity delegates +to_yaml+ / +from_yaml+ to this
    # class.
    #
    # Why a separate class? lutaml-model serialization calls
    # +public_send(attr_name)+ during +to_format+, which invokes the
    # getter method. Entity's field DSL getters read from +@properties+
    # and return domain objects (IRDI, source-language String, parsed
    # Array). The YAML attrs need flat types (String, Hash, Array).
    # Sharing the same name would make the getter return the wrong
    # type for serialization. Keeping the YAML model here avoids that
    # conflict while keeping the adapter "inside" Entity.
    #
    # Canonical YAML shape:
    #
    #   ---
    #   irdi: 0112/2///61360_4#AAA001
    #   type: class
    #   code: AAA001
    #   preferred_name:
    #     en: Vehicle
    #     fr: Véhicule
    #   class_type: ITEM_CLASS
    #   superclass: 0112/2///61360_4#AAA000
    #   applicable_properties:
    #     - 0112/2///61360_4#AAAP001
    #   extra:
    #     C016: released
    class Yaml < Lutaml::Model::Serializable
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
      attribute :description, :hash

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
      attribute :list_type, :string
      attribute :code_list, :string, collection: true
      attribute :term_irdis, :string, collection: true

      # ── Value-term-specific ─────────────────────────────────
      attribute :enumeration_code, :string

      # ── Relation-specific ───────────────────────────────────
      attribute :relation_type, :string
      attribute :codomain, :string
      attribute :formula, :string

      # ── View-control-specific ───────────────────────────────
      attribute :controlled_classes, :string, collection: true
      attribute :shown_properties, :string, collection: true

      # ── Catch-all for unknown properties (lossless) ────────
      attribute :extra, :hash

      # ── Conversion: Entity → Entity::Yaml ───────────────────
      def self.from_entity(entity)
        attrs = {
          irdi: entity.irdi&.to_s,
          type: entity.type&.to_s,
          code: entity.code,
          guid: entity[Opencdd::PropertyIds::MDC_P066],
          version: entity[Opencdd::PropertyIds::MDC_P002_1],
          revision: entity[Opencdd::PropertyIds::MDC_P002_2],
        }

        attrs[:preferred_name] = extract_ml(entity, Opencdd::PropertyIds::MDC_P004)
        attrs[:short_name]     = extract_ml(entity, Opencdd::PropertyIds::MDC_P005)
        attrs[:definition]     = extract_ml(entity, Opencdd::PropertyIds::MDC_P006)
        attrs[:note]           = extract_ml(entity, Opencdd::PropertyIds::MDC_P008)
        attrs[:remark]         = extract_ml(entity, Opencdd::PropertyIds::MDC_P009)
        attrs[:description]    = extract_ml(entity, Opencdd::PropertyIds::MDC_P112)

        case entity.type
        when :class
          attrs[:class_type] = entity.read_field(:class_type)&.to_s
          attrs[:superclass] = entity.read_field(:superclass_irdi)&.to_s
          attrs[:is_case_of] = entity.read_field(:is_case_of_irdis)&.map(&:to_s) || []
          attrs[:applicable_properties] = entity.read_field(:applicable_property_irdis)&.map(&:to_s) || []
          attrs[:imported_properties] = entity.read_field(:imported_property_irdis)&.map(&:to_s) || []
          attrs[:sub_class_selection] = entity.read_field(:sub_class_selection_irdis)&.map(&:to_s) || []
        when :property
          attrs[:data_type] = entity.read_field(:parsed_data_type)&.to_s
          attrs[:value_format] = entity.read_field(:parsed_value_format)&.to_s
          attrs[:definition_class] = entity.read_field(:definition_class_irdi)&.to_s
          attrs[:unit] = entity.read_field(:unit_irdi)&.to_s
          attrs[:condition] = entity.read_field(:condition)&.to_s
          attrs[:property_data_element_type] = entity.read_field(:property_data_element_type)&.to_s
        when :unit
          attrs[:unit_structure] = entity.read_field(:structure)
          attrs[:unit_text] = entity.read_field(:text_representation)
        when :value_list
          attrs[:list_type] = entity.read_field(:list_type)&.to_s
          attrs[:code_list] = entity.read_field(:code_list) || []
          attrs[:term_irdis] = entity.read_field(:term_irdis)&.map(&:to_s) || []
        when :value_term
          attrs[:enumeration_code] = entity.read_field(:enumeration_code)
        when :relation
          attrs[:relation_type] = entity.read_field(:relation_type)&.to_s
          attrs[:codomain] = entity.read_field(:codomain_irdi)&.to_s
          attrs[:formula] = entity.read_field(:formula)
        when :view_control
          attrs[:controlled_classes] = entity.read_field(:controlled_class_irdis)&.map(&:to_s) || []
          attrs[:shown_properties] = entity.read_field(:shown_property_irdis)&.map(&:to_s) || []
        end

        extra = extract_extra(entity)
        attrs[:extra] = extra if extra

        new(**attrs.compact)
      end

      # ── Conversion: Entity::Yaml → Entity ───────────────────
      def to_entity(_database = nil)
        props = {}

        props[Opencdd::PropertyIds::MDC_P066] = guid if guid
        props[Opencdd::PropertyIds::MDC_P002_1] = version if version
        props[Opencdd::PropertyIds::MDC_P002_2] = revision if revision

        merge_ml_into(props, Opencdd::PropertyIds::MDC_P004, preferred_name)
        merge_ml_into(props, Opencdd::PropertyIds::MDC_P005, short_name)
        merge_ml_into(props, Opencdd::PropertyIds::MDC_P006, definition)
        merge_ml_into(props, Opencdd::PropertyIds::MDC_P008, note)
        merge_ml_into(props, Opencdd::PropertyIds::MDC_P009, remark)
        merge_ml_into(props, Opencdd::PropertyIds::MDC_P112, description)

        props[Opencdd::PropertyIds::MDC_P011] = class_type if class_type
        props[Opencdd::PropertyIds::MDC_P010] = superclass if superclass
        props[Opencdd::PropertyIds::MDC_P013] = rejoin_set(is_case_of) if is_case_of&.any?
        props[Opencdd::PropertyIds::MDC_P014] = rejoin_set(applicable_properties) if applicable_properties&.any?
        props[Opencdd::PropertyIds::MDC_P090] = rejoin_set(imported_properties) if imported_properties&.any?
        props[Opencdd::PropertyIds::MDC_P016] = rejoin_set(sub_class_selection) if sub_class_selection&.any?

        props[Opencdd::PropertyIds::MDC_P022] = data_type if data_type
        props[Opencdd::PropertyIds::MDC_P024] = value_format if value_format
        props[Opencdd::PropertyIds::MDC_P021] = definition_class if definition_class
        props[Opencdd::PropertyIds::MDC_P041] = unit if unit
        props[Opencdd::PropertyIds::MDC_P028] = condition if condition
        props[Opencdd::PropertyIds::MDC_P020] = property_data_element_type if property_data_element_type

        props[Opencdd::PropertyIds::MDC_P023] = unit_structure if unit_structure
        props[Opencdd::PropertyIds::MDC_P023_1] = unit_text if unit_text

        props[Opencdd::PropertyIds::MDC_P046] = list_type if list_type
        props[Opencdd::PropertyIds::MDC_P044] = rejoin_set(code_list) if code_list&.any?
        props[Opencdd::PropertyIds::MDC_P043] = rejoin_set(term_irdis) if term_irdis&.any?

        props[Opencdd::PropertyIds::MDC_P044] = enumeration_code if enumeration_code

        props[Opencdd::PropertyIds::MDC_P200] = relation_type if relation_type
        props[Opencdd::PropertyIds::MDC_P203] = codomain if codomain
        props[Opencdd::PropertyIds::MDC_P204] = formula if formula

        props[Opencdd::PropertyIds::EXT_P002] = rejoin_set(controlled_classes) if controlled_classes&.any?
        props[Opencdd::PropertyIds::EXT_P003] = rejoin_set(shown_properties) if shown_properties&.any?

        extra&.each { |k, v| props[k.to_s] = v }

        entity_class = Opencdd::MetaClasses.entity_class_for_type(type&.to_sym) || Opencdd::Klass
        meta_code = Opencdd::MetaClasses.meta_class_for_type(type&.to_sym) || Opencdd::MetaClasses::MDC_C002

        entity_class.new(
          irdi: irdi ? Opencdd::IRDI.parse(irdi) : nil,
          properties: props,
          meta_class_irdi: Opencdd::IRDI.parse(meta_code),
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

      KNOWN_WIRE_IDS = %w[
        MDC_P002_1 MDC_P002_2 MDC_P066
        MDC_P004 MDC_P005 MDC_P006 MDC_P008 MDC_P009 MDC_P112
        MDC_P011 MDC_P010 MDC_P010_1
        MDC_P013 MDC_P014 MDC_P090 MDC_P016
        MDC_P022 MDC_P024 MDC_P021 MDC_P041 MDC_P028 MDC_P020
        MDC_P023 MDC_P023_1
        MDC_P046 MDC_P044 MDC_P043
        MDC_P200 MDC_P203 MDC_P204
        EXT_P002 EXT_P003
      ].freeze

      def self.extract_extra(entity)
        extra = {}
        entity.properties.each do |k, v|
          key = k.to_s
          next if key == "__row_index__"
          base = key.split(".", 2).first
          next if KNOWN_WIRE_IDS.include?(base)
          extra[key] = v
        end
        extra.empty? ? nil : extra
      end
      private_class_method :extract_extra

      def self.merge_ml(props, pid, hash)
        return unless hash&.any?
        hash.each { |lang, val| props["#{pid}.#{lang}"] = val }
      end

      private

      def merge_ml_into(props, pid, hash)
        self.class.merge_ml(props, pid, hash)
      end

      def rejoin_set(list)
        Opencdd::StructuredValues.rejoin(list)
      end
    end
  end
end
