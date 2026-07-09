# frozen_string_literal: true

require "set"

module Cdd
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
      database.root_classes.sort_by { |k| k.code.to_s }.each { |e| visit_class(e) }
    end

    def visit_class(klass)
      return if @seen.include?(klass.irdi)
      @seen << klass.irdi
      klass.children.sort_by { |c| c.code.to_s }.each { |c| visit_class(c) }
    end

    def visit_properties(database)
      database.properties.sort_by { |p| p.code.to_s }.each { |p| visit_property(p) }
    end

    def visit_units(database)
      database.units.sort_by { |u| u.code.to_s }.each { |u| visit_unit(u) }
    end

    def visit_value_lists(database)
      database.value_lists.sort_by { |v| v.code.to_s }.each { |v| visit_value_list(v) }
    end

    def visit_value_terms(database)
      database.value_terms.sort_by { |v| v.code.to_s }.each { |v| visit_value_term(v) }
    end

    def visit_relations(database)
      database.relations.sort_by { |r| r.code.to_s }.each { |r| visit_relation(r) }
    end

    def visit_view_controls(database)
      database.view_controls.sort_by { |v| v.code.to_s }.each { |v| visit_view_control(v) }
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
