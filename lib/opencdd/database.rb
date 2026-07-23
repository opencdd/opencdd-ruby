# frozen_string_literal: true

module Opencdd
  class Database
    Dictionary = Struct.new(
      :parcel_id, :source_language, :translation_languages, :meta_class_irdis,
      keyword_init: true,
    )

    FORCED_META_CLASSES = %w[MDC_C002 MDC_C003].freeze
    PARCEL_ID_PATTERN = /\A[A-Z0-9-]+\z/.freeze

    # Database is split into focused concern modules. Each module
    # is mixed in below and lives in its own file under
    # +lib/opencdd/database/+. The core class (this file) holds
    # entity identity, indexing, and the type-partitioned accessors.
    autoload :ParcelIntegration, "opencdd/database/parcel_integration"
    autoload :Queries,           "opencdd/database/queries"
    autoload :Finalization,      "opencdd/database/finalization"
    autoload :Mutations,         "opencdd/database/mutations"
    autoload :Persistence,       "opencdd/database/persistence"

    include Enumerable
    include Opencdd::Database::ParcelIntegration
    include Opencdd::Database::Queries
    include Opencdd::Database::Finalization
    include Opencdd::Database::Mutations
    include Opencdd::Database::Persistence

    attr_reader :workbooks, :unresolved_refs, :alias_table

    def self.load(path)
      Opencdd::Reader.load_database(path)
    end

    def self.load_workbook(path)
      Opencdd::Parcel::WorkbookReader.new(path).load_into(new)
    end

    def self.load_flat_dir(path)
      Opencdd::Parcel::FlatDirReader.new(path).load_into(new)
    end

    def self.load_sharded_dir(path)
      Opencdd::Parcel::ShardedDirReader.new(path).load_into(new)
    end

    def self.from_yaml(yaml)
      Opencdd::Model::YamlDatabase.from_yaml(yaml).to_database
    end

    def self.load_from_directory(path)
      Opencdd::Model::EntityStore.new(path).load_database
    end

    def initialize
      @entities_by_irdi = {}
      @entities_by_code = Hash.new { |h, k| h[k] = [] }
      @entities_by_type = Hash.new { |h, k| h[k] = [] }
      @workbooks = []
      @unresolved_refs = []
      @class_by_property_irdi = nil
      @symbol_table = {}
      @alias_table = Opencdd::AliasTable.new(defaults: true)
      @entity_sources = {}
    end

    def add_entity(entity)
      irdi = entity.irdi
      if irdi.nil?
        @unresolved_refs << [nil, entity]
        return self
      end

      if @entities_by_irdi.key?(irdi)
        existing = @entities_by_irdi[irdi]
        return self if existing.properties == entity.properties
        warn "Duplicate IRDI #{irdi} — overwriting"
      end

      @entities_by_irdi[irdi] = entity
      @entities_by_code[irdi.code] << entity if irdi.code
      @entities_by_type[entity.type] << entity if entity.type

      register_entity_symbols(entity)

      if entity.is_a?(Opencdd::Klass)
        entity.attach_database(self)
      end
      self
    end

    def register_symbol(name, entity)
      bind_symbol(name, entity)
    end

    def register_entity_symbols(entity)
      name = entity.is_a?(Opencdd::Entity) ? entity.preferred_name : nil
      bind_symbol(name, entity) if name
      code = entity.code
      bind_symbol(code, entity) if code
      self
    end

    def classes        ; @entities_by_type[:class]        || [] ; end
    def properties     ; @entities_by_type[:property]     || [] ; end
    def units          ; @entities_by_type[:unit]         || [] ; end
    def value_lists    ; @entities_by_type[:value_list]   || [] ; end
    def value_terms    ; @entities_by_type[:value_term]   || [] ; end
    def relations      ; @entities_by_type[:relation]     || [] ; end
    def view_controls  ; @entities_by_type[:view_control] || [] ; end
    def list_of_units  ; @entities_by_type[:list_of_unit] || [] ; end

    def entities_of_type(type)
      @entities_by_type[type.to_sym] || []
    end

    def entities
      @entities_by_irdi.values
    end

    def count(type = nil)
      type ? (@entities_by_type[type] || []).size : @entities_by_irdi.size
    end

    def each(&block)
      @entities_by_irdi.each_value(&block)
    end

    def to_s
      "#<#{self.class.name} classes=#{classes.size} properties=#{properties.size} " \
        "units=#{units.size} value_lists=#{value_lists.size} value_terms=#{value_terms.size} " \
        "relations=#{relations.size}>"
    end

    alias_method :inspect, :to_s

    private

    def bind_symbol(name, entity)
      key = name.to_s
      existing = @symbol_table[key]
      if existing && existing.irdi != entity.irdi
        warn "Symbol #{key.inspect} already bound to #{existing.irdi}; ignoring rebind to #{entity.irdi}"
        return self
      end
      @symbol_table[key] = entity
      self
    end
  end
end
