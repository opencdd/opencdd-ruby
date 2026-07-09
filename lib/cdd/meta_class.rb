# frozen_string_literal: true

module Cdd
  class MetaClass
    attr_reader :irdi, :name, :allowed_property_ids, :entity_class

    def initialize(irdi:, name:, entity_class: nil, allowed_property_ids: [])
      @irdi = irdi.to_s
      @name = name.to_s
      @entity_class = entity_class
      @allowed_property_ids = allowed_property_ids.map(&:to_s).freeze
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
      )
    end

    def to_s
      "#<#{self.class.name} #{@irdi} (#{@name}) properties=#{@allowed_property_ids.size}>"
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
        "EXT_C001" => "EXT_P001",
      }.freeze

      TYPE_BY_META_CLASS = {
        "MDC_C002" => :class,
        "MDC_C003" => :property,
        "MDC_C005" => :value_list,
        "MDC_C011" => :relation,
        "MDC_C009" => :unit,
        "MDC_C010" => :value_term,
        "EXT_C001" => :view_control,
      }.freeze

      @registry = nil

      class << self
        def common_property_ids
          Cdd::PropertyIds::REGISTRY.select { |_, e| e.applies_to == :all }.keys.freeze
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
            entity_class: Cdd::Klass,
            allowed_property_ids: common + %w[
              MDC_P010 MDC_P010_1 MDC_P011 MDC_P012 MDC_P013 MDC_P014 MDC_P014_1 MDC_P014_2
              MDC_P015 MDC_P015_1 MDC_P015_2 MDC_P016
              MDC_P090 MDC_P091 MDC_P093 MDC_P094 MDC_P094_1 MDC_P094_2
            ],
          )
          property_class = MetaClass.new(
            irdi: "MDC_C003",
            name: "Property",
            entity_class: Cdd::Property,
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
            entity_class: Cdd::ValueList,
            allowed_property_ids: common + %w[
              MDC_P043 MDC_P044 MDC_P045 MDC_P046
            ],
          )
          relation = MetaClass.new(
            irdi: "MDC_C011",
            name: "Relation",
            entity_class: Cdd::Relation,
            allowed_property_ids: common + %w[
              MDC_P200 MDC_P201 MDC_P202 MDC_P203 MDC_P204 MDC_P205
              MDC_P206 MDC_P207 MDC_P208 MDC_P209 MDC_P210 MDC_P211 MDC_P212
              MDC_P230 MDC_P231
            ],
          )
          unit = MetaClass.new(
            irdi: "MDC_C009",
            name: "Unit",
            entity_class: Cdd::Unit,
            allowed_property_ids: common + %w[
              MDC_P021 MDC_P023 MDC_P023_1 MDC_P023_2
            ],
          )
          value_term = MetaClass.new(
            irdi: "MDC_C010",
            name: "ValueTerm",
            entity_class: Cdd::ValueTerm,
            allowed_property_ids: common + %w[
              MDC_P018_1 MDC_P021 MDC_P022 MDC_P044 MDC_P045
            ],
          )
          view_control = MetaClass.new(
            irdi: "EXT_C001",
            name: "ViewControl",
            entity_class: Cdd::ViewControl,
            allowed_property_ids: common + %w[EXT_P002 EXT_P003],
          )
          {
            klass_class.irdi    => klass_class,
            property_class.irdi => property_class,
            value_list.irdi     => value_list,
            relation.irdi       => relation,
            unit.irdi           => unit,
            value_term.irdi     => value_term,
            view_control.irdi   => view_control,
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
