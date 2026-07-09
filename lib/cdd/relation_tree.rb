# frozen_string_literal: true

module Cdd
  class RelationTree
    class Node < Struct.new(:relation, :children, keyword_init: true)
      include Enumerable

      def each(&block)
        block.call(self)
        (children || []).each { |c| c.each(&block) }
      end

      def depth
        return 1 if children.nil? || children.empty?
        1 + children.map(&:depth).max
      end

      def size
        1 + (children || []).sum(&:size)
      end
    end

    attr_reader :database

    def initialize(database)
      @database = database
    end

    def for(root = nil, max_depth: 10)
      roots = root.nil? ? root_relations : [lookup_relation(root)].compact
      roots.map { |r| build_node(r, Set.new, max_depth) }
    end

    private

    def build_node(relation, path, max_depth)
      return nil if relation.nil?
      return nil if path.include?(relation.irdi)
      return nil if max_depth <= 0

      child_path = path + [relation.irdi]
      children = children_of(relation).map { |c| build_node(c, child_path, max_depth - 1) }.compact
      Node.new(relation: relation, children: children)
    end

    def children_of(relation)
      index.fetch(relation.irdi, [])
    end

    def root_relations
      database.relations.reject { |r| r.super_relation_irdi }
    end

    def lookup_relation(ref)
      database.resolve_reference(ref)
    end

    def index
      @index ||= build_index
    end

    def build_index
      hash = Hash.new { |h, k| h[k] = [] }
      database.relations.each do |r|
        parent_raw = r.properties[Cdd::PropertyIds::MDC_P212]
        next unless parent_raw && !parent_raw.to_s.strip.empty?
        parent = database.resolve_reference(parent_raw)
        next unless parent
        hash[parent.irdi] << r unless hash[parent.irdi].include?(r)
      end
      hash
    end
  end
end
