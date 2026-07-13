# frozen_string_literal: true

module Opencdd
  # CDD-native model layer backed by Lutaml::Model. Provides typed
  # attributes with semantic CDD names (preferred_name, superclass,
  # class_type) — not wire-format keys (MDC_P004, MDC_P010). YAML
  # is the canonical persistence format per user decision (2026-07-13).
  module Model
    autoload :YamlEntity,   "opencdd/model/yaml_entity"
    autoload :YamlDatabase, "opencdd/model/yaml_database"
    autoload :EntityStore,  "opencdd/model/entity_store"
  end
end
