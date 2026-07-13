# frozen_string_literal: true

require "set"

module Opencdd
  class EffectiveProperties
    Result = Struct.new(:properties, :sources, keyword_init: true) do
      include Enumerable

      def each
        return enum_for(:each) unless block_given?
        properties.each { |p| yield p }
      end

      def each_property
        return enum_for(:each_property) unless block_given?
        properties.each { |p| yield p }
      end

      def size
        properties.size
      end

      def include?(property)
        irdi = property.is_a?(Opencdd::IRDI) ? property : property&.irdi
        properties.any? { |p| p.irdi == irdi }
      end

      def codes
        properties.map(&:code)
      end

      def to_a
        properties.dup
      end
    end

    attr_reader :database

    def initialize(database)
      @database = database
    end

    def for(klass)
      k = resolve_klass(klass)
      return Result.new(properties: [], sources: {}) unless k
      acc = []
      sources = Hash.new { |h, kk| h[kk] = [] }
      accumulate(k, Set.new, acc, sources)
      Result.new(properties: acc.uniq { |p| p.irdi }, sources: sources)
    end

    def codes_for(klass)
      result = self.for(klass)
      result.properties.map(&:code)
    end

    private

    def resolve_klass(value)
      return value if value.is_a?(Opencdd::Klass)
      @database.resolve_reference(value)
    end

    def accumulate(klass, seen, acc, sources)
      return if seen.include?(klass.irdi)
      seen << klass.irdi

      add_declared_properties(klass, acc, sources)
      add_applicable_properties(klass, acc, sources)
      add_imported_properties(klass, acc, sources)
      walk_superclass(klass, seen, acc, sources)
      walk_is_case_of(klass, seen, acc, sources)
    end

    def add_declared_properties(klass, acc, sources)
      klass.declared_property_irdis.each do |irdi|
        prop = @database.find(irdi)
        next unless prop
        acc << prop
        sources[prop.irdi.to_s] << klass unless sources[prop.irdi.to_s].include?(klass)
      end
    end

    def add_applicable_properties(klass, acc, sources)
      klass.applicable_property_irdis.each do |irdi|
        prop = @database.find(irdi)
        next unless prop
        acc << prop
        sources[prop.irdi.to_s] << klass unless sources[prop.irdi.to_s].include?(klass)
      end
    end

    def add_imported_properties(klass, acc, sources)
      klass.imported_property_irdis.each do |irdi|
        prop = @database.find(irdi)
        next unless prop
        acc << prop
        sources[prop.irdi.to_s] << klass unless sources[prop.irdi.to_s].include?(klass)
      end
    end

    def walk_superclass(klass, seen, acc, sources)
      ref = klass.parent_irdi || klass.superclass_irdi
      return unless ref
      parent = @database.find(ref)
      return unless parent
      accumulate(parent, seen, acc, sources)
    end

    def walk_is_case_of(klass, seen, acc, sources)
      klass.is_case_of_irdis.each do |ref|
        target = @database.find(ref)
        next unless target
        accumulate(target, seen, acc, sources)
      end
    end
  end
end
