# frozen_string_literal: true

module Cdd
  module Validator
    ValidationError = Struct.new(:sheet, :row, :column, :rule, :message, keyword_init: true) do
      def to_s
        "#{sheet} row=#{row} col=#{column} [#{rule}]: #{message}"
      end
    end

    # Lazy-load validator rule classes. Autoload (rather than eager
    # `require`) keeps startup cheap when only one rule is needed.
    # The convention matches the rest of the codebase (see
    # lib/cdd/parcel.rb, lib/cdd/exporters.rb).
    autoload :Rule,             "cdd/validator/rule"
    autoload :IrdiRule,         "cdd/validator/irdi_rule"
    autoload :UniquenessRule,   "cdd/validator/uniqueness_rule"
    autoload :MandatoryRule,    "cdd/validator/mandatory_rule"
    autoload :TypeRule,         "cdd/validator/type_rule"
    autoload :EnumRule,         "cdd/validator/enum_rule"
    autoload :FormatRule,       "cdd/validator/format_rule"
    autoload :PatternRule,      "cdd/validator/pattern_rule"
    autoload :ReferenceRule,    "cdd/validator/reference_rule"
    autoload :SetRule,          "cdd/validator/set_rule"
    autoload :SynonymRule,      "cdd/validator/synonym_rule"
    autoload :ConditionRule,    "cdd/validator/condition_rule"
    autoload :DataTypeRule,     "cdd/validator/data_type_rule"
    autoload :HierarchyRule,    "cdd/validator/hierarchy_rule"
    autoload :Runner,           "cdd/validator/runner"
  end
end
