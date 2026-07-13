# frozen_string_literal: true

module Opencdd
  # Database-level YAML persistence helpers. Entity-level YAML
  # serialization lives on +Opencdd::Entity::Yaml+ (the deepened
  # adapter inside Entity's namespace). This module holds the
  # whole-database YAML wrapper and the per-entity file store.
  module Model
    autoload :YamlDatabase, "opencdd/model/yaml_database"
    autoload :EntityStore,  "opencdd/model/entity_store"
  end
end
