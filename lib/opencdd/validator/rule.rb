# frozen_string_literal: true

module Opencdd
  module Validator
    # Deep base class for all validator rules. Owns shared guards
    # that were previously copy-pasted across 12 rule subclasses:
    #
    #   - blank-value guard (skip empty cells unless +skip_blank?+
    #     is overridden to false)
    #   - code-column predicate
    #   - reference-kind predicate
    #
    # Subclasses implement +value_passes?+ (the narrow check) and
    # optionally override +applies?+ and +message+.
    class Rule
      REFERENCE_VALUE_KINDS = %i[identifier_ref set_of_refs class_ref].freeze

      def id
        raise NotImplementedError
      end

      # Default: applies to every entity. Override to narrow.
      def applies?(context)
        true
      end

      # Template method: skip blank values (unless the subclass
      # overrides +skip_blank?+), then delegate to +value_passes?+.
      def call(value, context)
        return true if skip_blank? && blank?(value)
        value_passes?(value, context)
      end

      def message(value, _context)
        "#{id}: value #{value.inspect} is invalid"
      end

      # ── Hooks for subclasses ────────────────────────────────────
      def value_passes?(value, context)
        raise NotImplementedError
      end

      # Most rules skip empty values — MandatoryRule overrides to
      # +false+ so it can flag missing mandatory cells.
      def skip_blank?
        true
      end

      # ── Shared predicates ───────────────────────────────────────
      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end

      def code_column?(context)
        return false unless context.entity && context.entity.meta_class_irdi
        code_pid = Opencdd::MetaClasses.code_property_id_for(context.entity.meta_class_irdi.code)
        context.column_iri == code_pid
      end

      def reference_kind?(context)
        REFERENCE_VALUE_KINDS.include?(context.value_kind)
      end
    end
  end
end
