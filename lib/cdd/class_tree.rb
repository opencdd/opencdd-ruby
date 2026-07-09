# frozen_string_literal: true

require "yaml"

module Cdd
  class ClassTree
    DEFAULT_FIELDS = %i[code name].freeze
    AVAILABLE_FIELDS = %i[code name irdi definition class_type].freeze

    include Enumerable

    attr_reader :database, :fields

    def initialize(database, fields: DEFAULT_FIELDS)
      @database = database
      @fields = fields
    end

    def roots
      @database.root_classes
    end

    def each
      return enum_for(:each) unless block_given?
      walk(roots, 0) { |k, _d| yield k }
    end

    def each_node
      return enum_for(:each_node) unless block_given?
      walk(roots, 0) { |k, d| yield k, d }
    end

    def to_h(max_depth: nil, fields: @fields)
      roots.map { |k| node_h(k, depth: 0, max_depth: max_depth, fields: fields) }
    end

    def to_yaml(max_depth: nil, fields: @fields)
      to_h(max_depth: max_depth, fields: fields).to_yaml
    end

    def subtree(klass, max_depth: nil, fields: @fields)
      node_h(klass, depth: 0, max_depth: max_depth, fields: fields)
    end

    def subtree_yaml(klass, **opts)
      subtree(klass, **opts).to_yaml
    end

    private

    def walk(nodes, depth)
      nodes.each do |node|
        yield node, depth
        walk(node.children, depth + 1) { |n, d| yield n, d }
      end
    end

    def node_h(klass, depth:, max_depth:, fields:)
      h = {}
      fields.each { |f| merge_field!(h, klass, f) }

      if max_depth.nil? || depth < max_depth
        kids = klass.children
        h["children"] = kids.map { |c| node_h(c, depth: depth + 1, max_depth: max_depth, fields: fields) } unless kids.empty?
      end
      h
    end

    def merge_field!(h, klass, field)
      case field
      when :code       then h["code"] = klass.code
      when :name       then h["name"] = klass.preferred_name
      when :irdi       then h["irdi"] = klass.irdi&.to_s
      when :definition then h["definition"] = klass.definition unless klass.definition.to_s.empty?
      when :class_type then h["class_type"] = klass.class_type.to_s if klass.class_type
      else raise ArgumentError, "unknown field #{field.inspect}; valid: #{AVAILABLE_FIELDS.inspect}"
      end
    end
  end
end
