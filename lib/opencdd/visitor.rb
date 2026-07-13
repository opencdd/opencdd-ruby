# frozen_string_literal: true

require "set"

module Opencdd
  class Visitor
    attr_reader :seen

    def initialize
      @seen = Set.new
    end

    def visit_database(database)
      visit_classes(database)
      visit_properties(database)
      visit_units(database)
      visit_value_lists(database)
      visit_value_terms(database)
      visit_relations(database)
      visit_view_controls(database)
      self
    end

    def visit_classes(database)
      each_sorted(database.root_classes) { |k| visit_class(k) }
    end

    def visit_class(klass)
      return if @seen.include?(klass.irdi)
      @seen << klass.irdi
      each_sorted(klass.children) { |c| visit_class(c) }
    end

    def visit_properties(database)
      each_sorted(database.properties) { |p| visit_property(p) }
    end

    def visit_units(database)
      each_sorted(database.units) { |u| visit_unit(u) }
    end

    def visit_value_lists(database)
      each_sorted(database.value_lists) { |v| visit_value_list(v) }
    end

    def visit_value_terms(database)
      each_sorted(database.value_terms) { |v| visit_value_term(v) }
    end

    def visit_relations(database)
      each_sorted(database.relations) { |r| visit_relation(r) }
    end

    def visit_view_controls(database)
      each_sorted(database.view_controls) { |v| visit_view_control(v) }
    end

    # Single source of truth for sort-by-code traversal. Was
    # duplicated as `.sort_by { |x| x.code.to_s }` in 7 methods.
    def each_sorted(entities)
      entities.sort_by { |e| e.code.to_s }.each { |e| yield e }
    end

    def visit_property(prop)
      @seen << prop.irdi if prop.irdi
    end

    def visit_unit(unit)
      @seen << unit.irdi if unit.irdi
    end

    def visit_value_list(vl)
      @seen << vl.irdi if vl.irdi
    end

    def visit_value_term(vt)
      @seen << vt.irdi if vt.irdi
    end

    def visit_relation(rel)
      @seen << rel.irdi if rel.irdi
    end

    def visit_view_control(vc)
      @seen << vc.irdi if vc.irdi
    end

    def reset!
      @seen.clear
      self
    end
  end
end
