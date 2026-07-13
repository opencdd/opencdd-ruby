# frozen_string_literal: true

module Opencdd
  module Validator
    class ReferenceRule < Rule
      def id
        "R08"
      end

      def applies?(context)
        %i[identifier_ref set_of_refs class_ref].include?(context.value_kind)
      end

      def call(value, context)
        return true if value.nil? || value.to_s.strip.empty?
        return false unless context.database
        refs(value).all? do |ref|
          parsed = Opencdd::IRDI.parse(ref)
          context.database.find(parsed) || context.database.find_by_code(ref.to_s)
        end
      end

      def message(value, _context)
        "R08: reference #{value.inspect} does not resolve in this database"
      end

      private

      def refs(value)
        # SSOT: same brace/paren/comma handling as every other
        # collection reader in the gem.
        Opencdd::StructuredValues.unwrap_and_split(value)
      end
    end
  end
end
