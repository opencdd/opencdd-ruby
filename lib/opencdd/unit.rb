# frozen_string_literal: true

module Opencdd
  class Unit < Opencdd::Entity
    # ── Pure field reads ─────────────────────────────────────────
    # MDC_P023/023_1/023_2 are :identifier_ref in REGISTRY but used
    # as raw strings for unit symbols/representations. Explicit :string
    # override preserves historical behavior.
    field :structure,            "MDC_P023",   :string
    field :text_representation,  "MDC_P023_1", :string
    field :sgml_representation,  "MDC_P023_2", :string
    field :definition_class_irdi, "MDC_P021"

    alias_method :symbol, :text_representation
  end
end
