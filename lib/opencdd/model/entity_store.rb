# frozen_string_literal: true

require "lutaml/store"
require "fileutils"

module Opencdd
  module Model
    # Per-entity YAML persistence using lutaml-store's DatabaseStore
    # as the backend. Each entity is stored as a single YAML file,
    # serialized via Lutaml::Model (Entity::Yaml — the deepened
    # adapter inside Entity's namespace). Diff-friendly at the entity
    # level — one git diff shows exactly which entity changed.
    #
    # Uses DatabaseStore#save_all and #load_all with format: :yaml
    # and layout: :separate (one file per entity). This is the
    # proper lutaml-store API — not the low-level adapter.set/get
    # bypass that the previous version used.
    #
    # Directory layout (managed by DatabaseStore's separate layout):
    #
    #   data/
    #   └── entities/
    #       ├── 0112_2___61360_4_AAA001.yaml
    #       ├── 0112_2___61360_4_AAA010.yaml
    #       └── ...
    #
    # The filename is the model's key field (irdi), sanitized by
    # the FileSystem adapter (non-alphanumeric chars → underscore).
    class EntityStore
      attr_reader :path, :store

      def initialize(path)
        @path = File.expand_path(path.to_s)
        FileUtils.mkdir_p(@path)
        @store = Lutaml::Store.new(
          adapter: :filesystem,
          adapter_options: { path: @path, extension: ".yaml" },
          models: [
            { model: Opencdd::Entity::Yaml, key: :irdi, dir: "entities" },
          ],
        )
      end

      # Save all entities from +database+ to individual YAML files
      # via DatabaseStore#save_all. Returns self.
      def save_database(database)
        yaml_entities = database.entities.filter_map do |entity|
          yaml = Opencdd::Entity::Yaml.from_entity(entity)
          yaml.irdi ? yaml : nil
        end
        @store.save_all(yaml_entities, path: @path, format: :yaml, layout: :separate)
        self
      end

      # Load all YAML files from the store into a Database.
      # Returns a finalized Database.
      def load_database(database = nil)
        database ||= Opencdd::Database.new
        yaml_entities = @store.load_all(
          Opencdd::Entity::Yaml,
          path: @path,
          format: :yaml,
          layout: :separate,
        )
        yaml_entities.each do |yaml_entity|
          entity = yaml_entity.to_entity(database)
          database.add_entity(entity)
        rescue StandardError => e
          warn "EntityStore: skipping entity: #{e.message}"
        end
        database.finalize!
        database
      end

      # Fetch a single entity's YAML model by key.
      def fetch(key)
        @store.fetch(model: Opencdd::Entity::Yaml, irdi: key)
      rescue Lutaml::Store::InvalidKeyError
        nil
      end
    end
  end
end
