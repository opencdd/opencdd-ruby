# frozen_string_literal: true

module Opencdd
  # CDD is a four-layer ontology (IEC 61360 §5):
  #
  #   M2 (meta-model)  — the meta-classes themselves: MDC_C002 Class,
  #                      MDC_C003 Property, MDC_C009 Unit, etc.
  #                      Fixed set per the standard. Each is modeled
  #                      by an +Opencdd::MetaClass+ instance.
  #   M1 (model)       — dictionary content: AAA001 Vehicle, AAAP001
  #                      vehicle_length, etc. Instances of M2
  #                      meta-classes, modeled by Opencdd::Entity
  #                      subclasses (Klass, Property, Unit, ...).
  #   M0 (data)        — real-world individuals: ORCA30-TH-0001 etc.
  #                      Instances of M1 classes.
  #
  # CDD's defining feature vs UML/RDF/OWL: at M1, a class declared
  # +class_type=CATEGORICAL_CLASS+ has subclasses that ARE themselves
  # classes but are also "instances" of the categorical class in the
  # powertype sense (used in CLASS_REFERENCE data types and
  # +sub_class_selection+). This two-level capability is the central
  # abstraction the model must preserve.
  class MetaClass
    # Parcel sheet-type label (string written to the sheetmap "type"
    # column). Single source of truth — Database, Writer, and
    # WorkbookReader all read from MetaClass#sheet_type instead of
    # maintaining parallel lookup tables.
    PARCEL_SHEET_TYPES = {
      class:        "CLASS",
      property:     "PROPERTY",
      value_list:   "ENUM",
      value_term:   "TERMINOLOGY",
      unit:         "UoM",
      relation:     "RELATION",
      view_control: "VIEWCONTROL",
    }.freeze

    attr_reader :irdi, :name, :allowed_property_ids, :entity_class,
                :type, :sheet_type

    def initialize(irdi:, name:, entity_class: nil, allowed_property_ids: [],
                   type: nil, sheet_type: nil)
      @irdi = irdi.to_s
      @name = name.to_s
      @entity_class = entity_class
      @allowed_property_ids = allowed_property_ids.map(&:to_s).freeze
      @type = type
      @sheet_type = sheet_type || (type ? PARCEL_SHEET_TYPES[type] : nil)
    end

    def code = @irdi

    def allows_property?(id)
      @allowed_property_ids.include?(id.to_s)
    end

    def merge(other)
      raise ArgumentError, "meta-class IRDI mismatch: #{other.irdi} != #{@irdi}" unless other.irdi == @irdi
      MetaClass.new(
        irdi: @irdi,
        name: @name,
        entity_class: @entity_class || other.entity_class,
        allowed_property_ids: (@allowed_property_ids + other.allowed_property_ids).uniq,
        type: @type || other.type,
        sheet_type: @sheet_type || other.sheet_type,
      )
    end

    def to_s
      "#<#{self.class.name} #{@irdi} (#{@name}) type=#{@type} properties=#{@allowed_property_ids.size}>"
    end
    alias_method :inspect, :to_s

    module MetaClasses
      CODE_PROPERTY_IDS = {
        "MDC_C002" => "MDC_P001_5",
        "MDC_C003" => "MDC_P001_6",
        "MDC_C005" => "MDC_P001_12",
        "MDC_C011" => "MDC_P001_13",
        "MDC_C009" => "MDC_P001_10",
        "MDC_C010" => "MDC_P001_11",
        "MDC_C0100" => "C0101",
        "MDC_C0101" => "MDC_P001_5",
        "EXT_C001" => "EXT_P001",
      }.freeze

      TYPE_BY_META_CLASS = {
        "MDC_C002" => :class,
        "MDC_C003" => :property,
        "MDC_C005" => :value_list,
        "MDC_C011" => :relation,
        "MDC_C009" => :unit,
        "MDC_C010" => :value_term,
        "MDC_C0100" => :list_of_unit,
        "MDC_C0101" => :det_classification,
        "IECCDD_001" => :det_classification,
        "EXT_C001" => :view_control,
      }.freeze

      @registry = nil

      class << self
        def common_property_ids
          Opencdd::PropertyIds::REGISTRY.select { |_, e| e.applies_to == :all }.keys.freeze
        end
        def register(meta_class)
          ensure_loaded
          existing = @registry[meta_class.irdi]
          merged = existing ? existing.merge(meta_class) : meta_class
          @registry[meta_class.irdi] = merged
          merged
        end

        def for(irdi)
          ensure_loaded
          @registry[irdi.to_s]
        end

        def all
          ensure_loaded
          @registry.values
        end

        def codes
          ensure_loaded
          @registry.keys
        end

        def reset!
          @registry = built_in_registry
          define_code_constants!
          self
        end

        def type_for(irdi)
          TYPE_BY_META_CLASS[irdi.to_s]
        end

        def code_property_id_for(irdi)
          CODE_PROPERTY_IDS[irdi.to_s]
        end

        # Reverse of +meta_class_for_type+: returns the Ruby entity
        # class (Opencdd::Klass, Opencdd::Property, etc.) registered
        # for a given +type+ Symbol. Single source of truth — used
        # by Database#add_workbook to dispatch entity construction
        # without maintaining its own type→class map.
        def entity_class_for_type(type)
          code = meta_class_for_type(type)
          return nil unless code
          ensure_loaded
          @registry[code]&.entity_class
        end

        # Parcel sheet-type label ("CLASS", "PROPERTY", "ENUM",
        # "TERMINOLOGY", "UoM", "RELATION", "VIEWCONTROL") for a
        # given +type+ Symbol. Used by Database#build_sheetmap_for
        # and Parcel::Writer instead of local lookup tables.
        def sheet_type_for_type(type)
          MetaClass::PARCEL_SHEET_TYPES[type.to_sym]
        end

        def sheet_type_for(irdi)
          ensure_loaded
          @registry[irdi.to_s]&.sheet_type
        end

        def meta_class_for_type(type)
          TYPE_BY_META_CLASS.key(type.to_sym) || TYPE_BY_META_CLASS.key(type.to_s.to_sym)
        end

        private

        def ensure_loaded
          return if @registry
          @registry = built_in_registry
          define_code_constants!
        end

        def define_code_constants!
          @registry.each_key do |code|
            unless const_defined?(code, false)
              const_set(code, code.freeze)
            end
          end
        end

        def built_in_registry
          common = common_property_ids
          klass_class = MetaClass.new(
            irdi: "MDC_C002",
            name: "Class",
            entity_class: Opencdd::Klass,
            type: :class,
            allowed_property_ids: common + %w[
              MDC_P010 MDC_P010_1 MDC_P011 MDC_P012 MDC_P013 MDC_P014 MDC_P014_1 MDC_P014_2
              MDC_P015 MDC_P015_1 MDC_P015_2 MDC_P016
              MDC_P090 MDC_P091 MDC_P093 MDC_P094 MDC_P094_1 MDC_P094_2
            ],
          )
          property_class = MetaClass.new(
            irdi: "MDC_C003",
            name: "Property",
            entity_class: Opencdd::Property,
            type: :property,
            allowed_property_ids: common + %w[
              MDC_P017 MDC_P018 MDC_P020 MDC_P021 MDC_P022 MDC_P023 MDC_P023_1 MDC_P023_2
              MDC_P024 MDC_P025_1 MDC_P025_2 MDC_P025_3
              MDC_P027_1 MDC_P027_2 MDC_P028
              MDC_P030 MDC_P031 MDC_P032 MDC_P033 MDC_P040
              MDC_P041 MDC_P042 MDC_P068 MDC_P096 MDC_P097
              MDC_P101 MDC_P102 MDC_P110 MDC_P111 MDC_P114
            ],
          )
          value_list = MetaClass.new(
            irdi: "MDC_C005",
            name: "ValueList",
            entity_class: Opencdd::ValueList,
            type: :value_list,
            allowed_property_ids: common + %w[
              MDC_P043 MDC_P044 MDC_P045 MDC_P046
            ],
          )
          relation = MetaClass.new(
            irdi: "MDC_C011",
            name: "Relation",
            entity_class: Opencdd::Relation,
            type: :relation,
            allowed_property_ids: common + %w[
              MDC_P200 MDC_P201 MDC_P202 MDC_P203 MDC_P204 MDC_P205
              MDC_P206 MDC_P207 MDC_P208 MDC_P209 MDC_P210 MDC_P211 MDC_P212
              MDC_P230 MDC_P231
            ],
          )
          unit = MetaClass.new(
            irdi: "MDC_C009",
            name: "Unit",
            entity_class: Opencdd::Unit,
            type: :unit,
            allowed_property_ids: common + %w[
              MDC_P021 MDC_P023 MDC_P023_1 MDC_P023_2
            ],
          )
          value_term = MetaClass.new(
            irdi: "MDC_C010",
            name: "ValueTerm",
            entity_class: Opencdd::ValueTerm,
            type: :value_term,
            allowed_property_ids: common + %w[
              MDC_P018_1 MDC_P021 MDC_P022 MDC_P044 MDC_P045
            ],
          )
          view_control = MetaClass.new(
            irdi: "EXT_C001",
            name: "ViewControl",
            entity_class: Opencdd::ViewControl,
            type: :view_control,
            allowed_property_ids: common + %w[EXT_P002 EXT_P003],
          )
          list_of_unit = MetaClass.new(
            irdi: "MDC_C0100",
            name: "ListOfUnit",
            entity_class: Opencdd::ListUnit,
            type: :list_of_unit,
            allowed_property_ids: common,
          )
          # cdd.iec.ch's search-export uses CLASS_ID:=IECCDD_001 (an
          # IEC-internal supplier scheme) — not a Parcel meta-class IRDI.
          # We register MDC_C0101 as the canonical meta-class IRDI; the
          # file's CLASS_ID is documentation, not the parsing gate.
          det_classification = MetaClass.new(
            irdi: "MDC_C0101",
            name: "DetClassification",
            entity_class: Opencdd::DetClassification,
            type: :det_classification,
            allowed_property_ids: common,
          )
          {
            klass_class.irdi    => klass_class,
            property_class.irdi => property_class,
            value_list.irdi     => value_list,
            relation.irdi       => relation,
            unit.irdi           => unit,
            value_term.irdi     => value_term,
            view_control.irdi   => view_control,
            list_of_unit.irdi   => list_of_unit,
            det_classification.irdi => det_classification,
          }
        end
      end
    end
  end

  MetaClasses = MetaClass::MetaClasses

  MetaClass::MetaClasses::TYPE_BY_META_CLASS.each_key do |code|
    MetaClasses.const_set(code, code.freeze) unless MetaClasses.const_defined?(code, false)
  end
end
