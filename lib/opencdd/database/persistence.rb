# frozen_string_literal: true

module Opencdd
  class Database
    # YAML persistence: whole-database YAML (to_yaml via
    # Model::YamlDatabase) and per-entity directory persistence
    # (save_to_directory via Model::EntityStore). Class-method
    # counterparts (from_yaml, load_from_directory) are defined
    # on Database directly in database.rb.
    module Persistence
      def to_yaml(*args)
        Opencdd::Model::YamlDatabase.from_database(self).to_yaml(*args)
      end

      def save_to_directory(path)
        Opencdd::Model::EntityStore.new(path).save_database(self)
        self
      end

      def semantically_equal?(other)
        return false unless other.is_a?(Opencdd::Database)
        return false unless entities.size == other.entities.size
        entities.all? do |e|
          oe = other.find(e.irdi)
          oe && e.type == oe.type && e.properties == oe.properties
        end
      end
    end
  end
end
