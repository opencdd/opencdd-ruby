# frozen_string_literal: true

module Opencdd
  module Validator
    class HierarchyRule < Rule
      def id
        "R14"
      end

      def applies?(_context)
        false
      end

      def call(_value, _context)
        true
      end

      def self.class_hierarchy_acyclic?(database)
        database.classes.each do |klass|
          return false if cycle_from?(klass, database)
        end
        true
      end

      def self.composition_hierarchy_acyclic?(database)
        visited = {}
        database.classes.each do |klass|
          return false if composition_cycle?(klass, database, visited, [])
        end
        true
      end

      class << self
        private

        def cycle_from?(klass, database, seen = [])
          return false if klass.nil?
          code = klass.irdi&.code
          return true if seen.include?(code)
          return false if code.nil?
          super_irdi = klass.superclass_irdi
          return false if super_irdi.nil?
          parent = database.find(super_irdi) || database.find_by_code(super_irdi.code)
          cycle_from?(parent, database, seen + [code])
        end

        def composition_cycle?(klass, database, visited, path)
          return false if klass.nil?
          code = klass.irdi&.code
          return true if path.include?(code)
          return false if visited[code]
          visited[code] = true
          props = klass.is_a?(Opencdd::Klass) && database ? klass.effective_properties(database) : []
          props.any? do |prop|
            dc = prop.is_a?(Opencdd::Property) ? prop.definition_class_irdi : nil
            next false if dc.nil?
            target = database.find(dc) || database.find_by_code(dc.code)
            next false if target.nil?
            composition_cycle?(target, database, visited, path + [code])
          end
        end
      end
    end
  end
end
