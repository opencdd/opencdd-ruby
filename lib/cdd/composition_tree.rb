# frozen_string_literal: true

require "set"

module Cdd
  class CompositionTree
    Node = Struct.new(:entity, :children, keyword_init: true) do
      include Enumerable

      def each(&block)
        return enum_for(:each) unless block
        walk(&block)
      end

      def walk(&block)
        return enum_for(:walk) unless block
        yield self
        children&.each { |c| c.walk(&block) }
        self
      end

      def leaf?
        children.nil? || children.empty?
      end

      def depth
        return 1 if leaf?
        1 + children.map(&:depth).max
      end

      def size
        walk.count
      end

      def classes
        walk.filter_map { |n| n.entity if n.entity.is_a?(Cdd::Klass) }
      end

      def properties
        walk.filter_map { |n| n.entity if n.entity.is_a?(Cdd::Property) }
      end
    end

    attr_reader :database

    def initialize(database)
      @database = database
    end

    def for(klass, max_depth: 10)
      build_class_node(klass, Set.new, 0, max_depth)
    end

    private

    def build_class_node(value, path, depth, max_depth)
      klass = resolve_klass(value)
      return nil unless klass

      children =
        if path.include?(klass.irdi) || depth >= max_depth
          []
        else
          build_property_children(klass, path + [klass.irdi], depth + 1, max_depth)
        end

      Node.new(entity: klass, children: children)
    end

    def build_property_children(klass, path, depth, max_depth)
      result = @database.effective_properties.for(klass)
      result.map do |prop|
        build_property_node(prop, path, depth, max_depth)
      end
    end

    def build_property_node(prop, path, depth, max_depth)
      sub = []
      if depth < max_depth && prop.is_a?(Cdd::Property)
        class_reference_target(prop) do |target|
          node = build_class_node(target, path, depth, max_depth)
          sub << node if node
        end
        definition_class_subclasses(prop) do |target|
          node = build_class_node(target, path, depth, max_depth)
          sub << node if node
        end
      end
      Node.new(entity: prop, children: sub)
    end

    def class_reference_target(prop)
      return unless prop.class_reference?
      dt = prop.parsed_data_type
      return unless dt.is_a?(Cdd::DataType::ClassReference)
      target = @database.resolve_reference(dt.class_identifier)
      yield target if target.is_a?(Cdd::Klass)
    end

    def definition_class_subclasses(prop)
      dc_irdi = prop.definition_class_irdi
      return unless dc_irdi
      definition_class = @database.find(dc_irdi)
      return unless definition_class.is_a?(Cdd::Klass) && definition_class.categorical?
      definition_class.children.each do |child|
        yield child if child.is_a?(Cdd::Klass)
      end
    end

    def resolve_klass(value)
      return value if value.is_a?(Cdd::Klass)
      resolved = @database.resolve_reference(value)
      resolved if resolved.is_a?(Cdd::Klass)
    end
  end
end
