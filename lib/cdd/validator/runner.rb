# frozen_string_literal: true

module Cdd
  module Validator
    class Runner
      RuleContext = Struct.new(
        :database, :entity, :column_iri, :value_kind,
        :data_type, :value_format, :pattern, :requirement,
        :enum_terms_resolver,
        keyword_init: true,
      ) do
        def requirement_mandatory?
          requirement.to_s.upcase == "MAND" || requirement.to_s.upcase == "KEY"
        end

        def enum_terms_for(data_type)
          return [] unless enum_terms_resolver
          enum_terms_resolver.call(data_type)
        end
      end

      RULES = [
        IrdiRule.new,
        UniquenessRule.new,
        MandatoryRule.new,
        TypeRule.new,
        EnumRule.new,
        FormatRule.new,
        PatternRule.new,
        ReferenceRule.new,
        SetRule.new,
        SynonymRule.new,
        ConditionRule.new,
        DataTypeRule.new,
      ].freeze

      def self.run(database, enum_terms_resolver: nil)
        errors = []
        database.entities.each do |entity|
          validate_entity(entity, database, errors, enum_terms_resolver)
        end
        unless HierarchyRule.class_hierarchy_acyclic?(database)
          errors << ValidationError.new(
            sheet: nil, row: nil, column: nil, rule: "R14",
            message: "R14: class hierarchy contains a cycle",
          )
        end
        errors
      end

      def self.validate_entity(entity, database, errors, enum_terms_resolver)
        meta = Cdd::MetaClasses.for(entity.meta_class_irdi&.code)
        schema = entity.schema
        entity.each_property do |column_iri, value|
          next if column_iri == "__row_index__"
          context = build_context(
            database: database, entity: entity, column_iri: column_iri,
            value: value, schema: schema, meta: meta,
            enum_terms_resolver: enum_terms_resolver,
          )
          RULES.each do |rule|
            next unless rule.applies?(context)
            next if rule.call(value, context)
            errors << ValidationError.new(
              sheet: entity.meta_class_irdi&.code,
              row: entity.irdi&.to_s,
              column: column_iri,
              rule: rule.id,
              message: rule.message(value, context),
            )
          end
        end
      end

      def self.build_context(database:, entity:, column_iri:, value:, schema:, meta:, enum_terms_resolver:)
        base = column_iri.to_s.split(".").first
        entry = Cdd::PropertyIds::REGISTRY[base]
        kind = entry&.value_kind
        column_schema = schema&.column_for(base)
        RuleContext.new(
          database: database,
          entity: entity,
          column_iri: base,
          value_kind: kind,
          data_type: derived_data_type(entity, base, column_schema),
          value_format: column_schema&.value_format,
          pattern: column_schema&.pattern,
          requirement: column_schema&.requirement,
          enum_terms_resolver: enum_terms_resolver,
        )
      end

      def self.derived_data_type(entity, base, column_schema)
        return column_schema&.data_type if column_schema&.data_type
        return entity.data_type if entity.is_a?(Cdd::Property) && base == Cdd::PropertyIds::MDC_P022
        nil
      end
    end
  end
end
