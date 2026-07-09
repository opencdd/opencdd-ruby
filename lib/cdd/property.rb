# frozen_string_literal: true

module Cdd
  class Property < Cdd::Entity
    # Wire-format aliases for the data_type string. Used by #data_type
    # to canonicalize the raw value before exposing it.
    DATA_TYPE_ALIASES = {
      "STRING_TYPE"              => :string,
      "TRANSLATABLE_STRING_TYPE" => :translatable_string,
      "REAL_MEASURE_TYPE"        => :real_measure,
      "INTEGER_MEASURE_TYPE"     => :integer_measure,
      "INT_MEASURE_TYPE"         => :integer_measure,
      "REAL_TYPE"                => :real,
      "INTEGER_TYPE"             => :integer,
      "INT_TYPE"                 => :integer,
      "BOOLEAN_TYPE"             => :boolean,
      "DATE_TYPE"                => :date,
      "DATETIME_TYPE"            => :date_time,
      "DATE_TIME_TYPE"           => :date_time,
      "TIME_TYPE"                => :time,
      "IRDI_TYPE"                => :irdi,
      "ICID_STRING"              => :irdi,
      "ICID_STRING_TYPE"         => :irdi,
      "URL_TYPE"                 => :url,
      "MIME_TYPE"                => :mime,
      "FILE_TYPE"                => :file,
      "COMPLEX_TYPE"             => :complex,
    }.freeze

    # ── Pure field reads (value_kind + multilingual resolved from
    #     PropertyIds::REGISTRY). Explicit :string override where the
    #     original code returned the raw value (REGISTRY kind would
    #     otherwise coerce to IRDI etc.). ──────────────────────────
    field :symbol_in_text,         "MDC_P025_1", :string
    field :value_format,           "MDC_P024",   :string
    field :constraint,             "MDC_P068",   :string
    field :type_classification,    "MDC_P033",   :string
    field :source_document,        "MDC_P006_1", :string
    field :coded_name,             "MDC_P018",  :string
    field :definition_class_irdi,  "MDC_P021"
    field :class_value_assignment, "MDC_P017"
    field :unit_irdi,              "MDC_P041"
    field :alternative_unit_irdis, "MDC_P042"

    # ── Computed fields with custom readers ──────────────────────
    #     (synthetic: true. value_kind is informational only.)
    # `data_type` is NOT a DSL field — the model's #data_type method
    # returns a symbol (:real, :string, etc.) for callers. The wire-
    # format string ("REAL_TYPE") comes from parsed_data_type.to_s
    # and is emitted explicitly by Exporters::Json#property_node.
    field :parsed_data_type,       synthetic: true, reader: :read_parsed_data_type
    field :data_element_type,      synthetic: true, reader: :read_property_data_element_type, as: "data_element_type"
    field :property_data_element_type,
          synthetic: true, reader: :read_property_data_element_type
    field :parsed_value_format,    synthetic: true, reader: :read_parsed_value_format
    field :condition_raw,          "MDC_P028", synthetic: true, reader: :read_condition_raw
    field :condition,              synthetic: true, reader: :read_condition
    field :formula,                synthetic: true, reader: :read_formula

    # Model-side data_type — returns the canonical symbol form.
    def data_type
      raw = properties[Cdd::PropertyIds::MDC_P022]
      DATA_TYPE_ALIASES[raw] || raw
    end

    # ── Predicates and methods with arguments stay as regular
    #     methods. The DSL is for fields, not behavior. ───────────

    def class_reference?
      parsed_data_type.is_a?(Cdd::DataType::ClassReference)
    end

    def enum?
      parsed_data_type.is_a?(Cdd::DataType::EnumStringType) ||
        parsed_data_type.is_a?(Cdd::DataType::EnumReferenceType)
    end

    def conditional?
      det = property_data_element_type
      det && (det.condition? || det.dependent?)
    end

    def active_for?(bindings)
      return true unless conditional?
      cond = condition
      cond ? cond.satisfied_by?(bindings) : true
    end

    def attaches_to(*_args)
      raise NotImplementedError,
            "Property#attaches_to is provided by Cdd::Database; use db.properties_of(klass)"
    end
    alias_method :applies_to, :attaches_to

    private

    def read_data_type
      raw = properties[Cdd::PropertyIds::MDC_P022]
      DATA_TYPE_ALIASES[raw] || raw
    end

    def read_parsed_data_type
      Cdd::DataType.parse_or_string(properties[Cdd::PropertyIds::MDC_P022])
    end

    def read_parsed_value_format
      Cdd::ValueFormat.parse(properties[Cdd::PropertyIds::MDC_P024])
    end

    def read_condition_raw
      properties[Cdd::PropertyIds::MDC_P028]
    end

    def read_condition
      @condition ||= Cdd::Condition.parse(properties[Cdd::PropertyIds::MDC_P028])
    rescue ArgumentError
      # IEC CDD occasionally stores a bare class-reference set in the
      # condition column (e.g. "{0112/2///62683#ACE132}") instead of
      # a `left OP right` boolean expression. Condition's grammar
      # rejects that shape; treat it as nil rather than crashing the
      # import. Tracked in TODO.full-cdd/17-condition-grammar-fix.md.
      @condition = nil
    end

    def read_property_data_element_type
      @property_data_element_type ||=
        Cdd::PropertyDataTypeElement.parse(properties[Cdd::PropertyIds::MDC_P020])
    end

    def read_formula
      properties[Cdd::PropertyIds::MDC_P027_1] ||
        properties[Cdd::PropertyIds::MDC_P027_2]
    end
  end
end
