# frozen_string: true

require "lutaml/model"

module Opencdd
  module Model
    # CDD-native YAML database. Wraps a collection of Entity::Yaml
    # objects with dictionary-level metadata (source language,
    # translation languages). Serializes to YAML via lutaml-model
    # — no hand-rolled serialization on the model class itself.
    #
    # YAML shape:
    #
    #   ---
    #   source_language: en
    #   translation_languages:
    #     - fr
    #     - ja
    #   entities:
    #     - irdi: 0112/2///61360_4#AAA001
    #       type: class
    #       code: AAA001
    #       preferred_name:
    #         en: Vehicle
    #       ...
    class YamlDatabase < Lutaml::Model::Serializable
      attribute :source_language, :string, default: "en"
      attribute :translation_languages, :string, collection: true
      attribute :entities, Opencdd::Entity::Yaml, collection: true

      def self.from_database(database)
        new(
          source_language: "en",
          translation_languages: [],
          entities: database.entities.map { |e| Opencdd::Entity::Yaml.from_entity(e) },
        )
      end

      def to_database(database = nil)
        database ||= Opencdd::Database.new
        entities.each { |ye| database.add_entity(ye.to_entity(database)) }
        database.finalize!
        database
      end
    end
  end
end
