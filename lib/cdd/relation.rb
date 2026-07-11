# frozen_string_literal: true

module Cdd
  class Relation < Cdd::Entity
    RELATION_TYPES = {
      "FUNCTION"    => :function,
      "PREDICATION" => :predication,
    }.freeze

    # ── Pure field reads ─────────────────────────────────────────
    field :domain_of_function_irdis, "MDC_P202"
    field :codomain_irdi,            "MDC_P203"
    field :formula,                  "MDC_P204", :string
    field :formula_language,         "MDC_P205", :string
    field :external_solver,          "MDC_P206", :string
    field :trigger_event,            "MDC_P207", :string
    field :domain_element_type,      "MDC_P208", :string
    field :codomain_element_type,    "MDC_P209", :string
    field :role,                     "MDC_P210", :string
    field :segment,                  "MDC_P211", :string
    field :super_relation_irdi,      "MDC_P212"

    # ── Computed fields with block-form readers ──────────────────
    field(:relation_type, synthetic: true) do
      @relation_type_value ||= Cdd::RelationType.parse(properties[Cdd::PropertyIds::MDC_P200]) ||
        parse_legacy_relation_type
    end
    field(:domain_irdis, synthetic: true) do
      list = []
      [Cdd::PropertyIds::MDC_P201, Cdd::PropertyIds::MDC_P202].each do |key|
        list.concat(parse_irdi_list(properties[key]))
      end
      list
    end

    def relation_type_symbol
      value = relation_type
      value ? value.to_sym : nil
    end

    def predication?
      rt = relation_type
      rt ? rt.predication? : false
    end

    def function?
      rt = relation_type
      rt ? rt.function? : false
    end

    def association?
      rt = relation_type
      rt ? rt.association? : false
    end

    def aggregation?
      rt = relation_type
      rt ? rt.aggregation? : false
    end

    def composition?
      rt = relation_type
      rt ? rt.composition? : false
    end

    def generalization?
      rt = relation_type
      rt ? rt.generalization? : false
    end

    def specialization?
      rt = relation_type
      rt ? rt.specialization? : false
    end

    private

    def parse_legacy_relation_type
      raw = properties[Cdd::PropertyIds::MDC_P200]
      sym = RELATION_TYPES[raw]
      return nil unless sym
      case sym
      when :function    then Cdd::RelationType.new("FUNCTION")
      when :predication then Cdd::RelationType.new("PREDICATION")
      end
    end
  end
end
