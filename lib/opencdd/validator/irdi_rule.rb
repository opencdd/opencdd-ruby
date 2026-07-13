# frozen_string_literal: true

module Opencdd
  module Validator
    class IrdiRule < Rule
      FULL_PATTERN = %r{
        \A
        [^/#\s]+
        /
        [^/#\s]*
        ///
        [^/#\s]+
        \#
        [^#\s]+
        (?:\#\#\d+)?
        (?:\#\#\#[^#]+)?
        \z
      }x.freeze

      SHORT_PATTERN = /\A[A-Za-z0-9_]+\z/.freeze

      def id
        "R01"
      end

      def applies?(context)
        code_column?(context) || reference_column?(context)
      end

      def call(value, context)
        return true if value.nil? || value.to_s.strip.empty?
        s = value.to_s.strip
        if reference_column?(context)
          return true unless Opencdd::IRDI.parse(s).nil?
          return false
        end
        FULL_PATTERN.match?(s) || SHORT_PATTERN.match?(s) ? true : false
      end

      def message(value, _context)
        "R01: malformed IRDI/ICID #{value.inspect}"
      end

      private

      def code_column?(context)
        context.column_iri&.start_with?(Opencdd::PropertyIds::MDC_P001) ||
          context.column_iri == Opencdd::PropertyIds::EXT_P001
      end

      def reference_column?(context)
        %i[identifier_ref set_of_refs class_ref].include?(context.value_kind)
      end
    end
  end
end

