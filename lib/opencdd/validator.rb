# frozen_string_literal: true

module Opencdd
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
    autoload :Rule,             "opencdd/validator/rule"
    autoload :IrdiRule,         "opencdd/validator/irdi_rule"
    autoload :UniquenessRule,   "opencdd/validator/uniqueness_rule"
    autoload :MandatoryRule,    "opencdd/validator/mandatory_rule"
    autoload :TypeRule,         "opencdd/validator/type_rule"
    autoload :EnumRule,         "opencdd/validator/enum_rule"
    autoload :FormatRule,       "opencdd/validator/format_rule"
    autoload :PatternRule,      "opencdd/validator/pattern_rule"
    autoload :ReferenceRule,    "opencdd/validator/reference_rule"
    autoload :SetRule,          "opencdd/validator/set_rule"
    autoload :SynonymRule,      "opencdd/validator/synonym_rule"
    autoload :ConditionRule,    "opencdd/validator/condition_rule"
    autoload :DataTypeRule,     "opencdd/validator/data_type_rule"
    autoload :HierarchyRule,      "opencdd/validator/hierarchy_rule"
    autoload :ClassReferenceRule, "opencdd/validator/class_reference_rule"
    autoload :Runner,             "opencdd/validator/runner"

    module_function

    # Composite runner — applies every rule to every entity's every
    # property, plus the database-level invariants (class-hierarchy
    # acyclicity). Returns an Array of +ValidationError+ records
    # that the UI / CI can render as a clickable list.
    def run(database, **opts)
      Runner.run(database, **opts)
    end

    # ── Reusable predicates (plan 10 public API). Each wraps an
    #     existing rule class so the OpenCDD Editor's live validator
    #     (TS port) can share the same semantics as the Ruby gem. ──

    def irdi_well_formed?(value)
      return false if value.nil? || value.to_s.strip.empty?
      !Opencdd::IRDI.parse(value.to_s).nil?
    rescue Opencdd::IRDI::ParseError
      false
    end

    def mandatory_present?(value)
      !value.nil? && !value.to_s.strip.empty?
    end

    def pattern_valid?(value, pattern)
      return false if pattern.nil? || pattern.to_s.empty?
      Regexp.new(pattern).match?(value.to_s)
    rescue RegexpError
      false
    end

    def class_hierarchy_acyclic?(database)
      HierarchyRule.class_hierarchy_acyclic?(database)
    end
  end
end
