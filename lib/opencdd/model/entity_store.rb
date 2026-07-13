# frozen_string: true

require "lutaml/store"
require "fileutils"

module Opencdd
  module Model
    # Per-entity YAML persistence using lutaml-store as the backend.
    # Each entity is stored as a single YAML file in a directory layout,
    # serialized via Lutaml::Model (Entity::Yaml — the deepened adapter
    # inside Entity's namespace). Diff-friendly at the entity level —
    # one git diff shows exactly which entity changed.
    #
    # Directory layout (managed by lutaml-store's FileSystem adapter):
    #
    #   data/
    #   └── entities/
    #       ├── AA/
    #       │   ├── AAA001.data
    #       │   └── AAA010.data
    #       └── ...
    #
    # The FileSystem adapter shards by first 2 chars for scalability.
    class EntityStore
      attr_reader :path, :store

      def initialize(path)
        @path = File.expand_path(path.to_s)
        FileUtils.mkdir_p(@path)
        @store = Lutaml::Store.new(
          adapter: :filesystem,
          adapter_options: { path: @path },
          models: [
            { model: Opencdd::Entity::Yaml, key: :irdi, dir: "entities" },
          ],
        )
      end

      def save_database(database)
        database.entities.each do |entity|
          yaml_entity = Opencdd::Entity::Yaml.from_entity(entity)
          key = safe_key(yaml_entity.irdi || yaml_entity.code)
          next unless key
          yaml_str = yaml_entity.to_yaml
          @store.store.adapter.set(key, yaml_str)
        end
        self
      end

      def load_database(database = nil)
        database ||= Opencdd::Database.new
        @store.store.adapter.keys.each do |key|
          raw = @store.store.adapter.get(key)
          next unless raw
          begin
            yaml_entity = Opencdd::Entity::Yaml.from_yaml(raw)
            entity = yaml_entity.to_entity(database)
            database.add_entity(entity)
          rescue StandardError => e
            warn "EntityStore: skipping #{key}: #{e.message}"
          end
        end
        database.finalize!
        database
      end

      def fetch(key)
        raw = @store.store.adapter.get(safe_key(key))
        return nil unless raw
        Opencdd::Entity::Yaml.from_yaml(raw)
      end

      private

      def safe_key(key)
        return nil if key.nil? || key.to_s.strip.empty?
        key.to_s.split("#").last || key.to_s
      end
    end
  end
end
