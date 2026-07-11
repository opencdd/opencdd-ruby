# frozen_string_literal: true

module Cdd
  class ValueTerm < Cdd::Entity
    # ── Pure field reads ─────────────────────────────────────────
    # MDC_P022 is :class_ref in REGISTRY but ValueTerm treats it as
    # a raw type-string ("STRING_TYPE", etc.).
    field :enumeration_code,    "MDC_P044", :string
    field :definition_class_irdi, "MDC_P021"
    field :data_type,           "MDC_P022", :string

    # ── Computed fields with block-form readers ──────────────────
    # The value-list backref can live under MDC_P018_1, MDC_P045, or
    # a non-standard VALUE_LIST_IRDI key. Try each in turn.
    field(:value_list_irdi, synthetic: true) do
      raw = properties[Cdd::PropertyIds::MDC_P018_1] ||
            properties[Cdd::PropertyIds::MDC_P045]   ||
            properties["VALUE_LIST_IRDI"]
      Cdd::IRDI.parse(raw) if raw
    end

    alias_method :term_code, :enumeration_code
  end
end
