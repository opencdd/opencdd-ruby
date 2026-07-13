# frozen_string_literal: true

module Opencdd
  module Validator
    # R16 — CLASS_REFERENCE target validation.
    #
    # When a property's data_type is +CLASS_REFERENCE(CategoricalClass)+
    # (or the column carries a CLASS_REFERENCE schema), the value IRDI
    # must resolve to an entity that is a valid powertype instance of
    # the named categorical class — i.e. one of its
    # +categorical_instances+.
    #
    # This rule closes the loop on CDD's powertype semantics: a
    # CLASS_REFERENCE data type doesn't just say "this is an IRDI";
    # it says "this is an IRDI of an instance of this categorical
    # class." Plain reference resolution (R08) doesn't catch the
    # categorical constraint.
    #
    # Example: a Property `engine_type: CLASS_REFERENCE(EngineType)`
    # whose value is "AAA001" (Vehicle) should fail — Vehicle is
    # not a categorical instance of EngineType. Only SingleDiesel /
    # TwinDiesel / ElectricHybrid (EngineType's subclasses) pass.
    class ClassReferenceRule < Rule
      def id
        "R16"
      end

      def applies?(context)
        return false unless context.database
        parsed = parse_data_type(context)
        parsed.is_a?(Opencdd::DataType::ClassReference)
      end

      def call(value, context)
        return true if value.nil? || value.to_s.strip.empty?
        target = categorical_target(context)
        return true unless target # cannot validate without target resolution

        refs(value).all? { |ref| context.database.valid_class_reference?(target, ref) }
      end

      def message(value, context)
        target = categorical_target(context)
        name = target ? target.code : "<unresolved>"
        "R16: CLASS_REFERENCE(#{name}) value #{value.inspect} is not a valid powertype instance"
      end

      private

      def parse_data_type(context)
        raw = context.data_type
        return nil if raw.nil? || raw.to_s.strip.empty?
        Opencdd::DataType.parse(raw.to_s)
      rescue ArgumentError
        nil
      end

      def categorical_target(context)
        @cache ||= {}
        key = context.data_type
        return @cache[key] if @cache.key?(key)
        parsed = parse_data_type(context)
        @cache[key] = parsed ? resolve_target(parsed, context) : nil
      end

      def resolve_target(parsed, context)
        identifier = parsed.class_identifier
        return nil unless identifier
        context.database.resolve_reference(identifier)
      end

      def refs(value)
        Opencdd::StructuredValues.unwrap_and_split(value)
      end
    end
  end
end
