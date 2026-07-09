# frozen_string_literal: true

module Cdd
  module Validator
    class UniquenessRule < Rule
      def id
        "R02"
      end

      def applies?(context)
        code_column?(context)
      end

      def call(value, context)
        return true if value.nil? || value.to_s.strip.empty?
        peers = context.database.entities.filter_map { |e| e.irdi&.code if e.type == context.entity.type }
        peers.tally[value.to_s] == 1
      end

      def message(value, _context)
        "R02: code #{value.inspect} is not unique within its sheet"
      end

      private

      def code_column?(context)
        context.column_iri&.start_with?(Cdd::PropertyIds::MDC_P001) ||
          context.column_iri == Cdd::PropertyIds::EXT_P001
      end
    end
  end
end
