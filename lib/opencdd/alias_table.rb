# frozen_string_literal: true

module Opencdd
  class AliasTable
    DUPLICATE_ALIAS = "duplicate alias: %<name>s"

    def initialize(defaults: true)
      @table = defaults ? PropertyIds.alias_map.dup : {}
    end

    def declare(alias_name, property_id)
      name = alias_name.to_s
      existing = @table[name]
      if existing
        if existing == property_id.to_s
          return self
        end
        raise ArgumentError, format(DUPLICATE_ALIAS, name: name)
      end
      raise ArgumentError, "unknown property id: #{property_id}" unless PropertyIds.entry(property_id)
      @table[name] = property_id.to_s
      self
    end

    def redeclare(alias_name, property_id)
      name = alias_name.to_s
      raise ArgumentError, "unknown property id: #{property_id}" unless PropertyIds.entry(property_id)
      @table[name] = property_id.to_s
      self
    end

    def resolve(name)
      @table[name.to_s]
    end

    def key?(name)
      @table.key?(name.to_s)
    end

    def each(&block)
      @table.each(&block)
    end

    def to_h
      @table.dup
    end

    def size
      @table.size
    end
  end
end
