# frozen_string_literal: true

require "json"

module Opencdd
  module Parcel
    # Reads the harvester's <code>_entity.json</code> sidecar format
    # and converts it into Opencdd::Entity::VersionHistory entries
    # and stub entities for cross-reference resolution.
    #
    # Extracted from ShardedDirReader so the JSON-shape concern has
    # its own home and can be tested with a hash fixture instead of
    # requiring a full directory tree on disk.
    #
    # The sidecar schema (produced by harvest/download_versions.py):
    #
    #   {
    #     "irdi": "0112/2///62656_1#AAA001",
    #     "entity_type": "class",                 # Symbol
    #     "current_version_dir": "ABC123...",     # UNID subfolder name
    #     "versions": [
    #       { "version": 1, "revision": 0, "status": "Released",
    #         "timestamp": "2024-01-15T10:23:00Z", "user": "...",
    #         "change_request_id": "...", "unid": "...",
    #         "is_current": true }
    #     ]
    #   }
    class EntityManifest
      attr_reader :data, :path

      # Returns a manifest for +entity_dir+, or +nil+ when no
      # +_entity.json+ lives there or the file is unparseable.
      def self.read(entity_dir)
        path = File.join(entity_dir, "_entity.json")
        return nil unless File.file?(path)
        data = JSON.parse(File.read(path))
        new(data, path)
      rescue JSON::ParserError
        nil
      end

      def initialize(data, path = nil)
        @data = data
        @path = path
      end

      # IRDI of the entity this manifest describes, or +nil+.
      def irdi
        raw = @data["irdi"]
        return nil if raw.nil?
        Opencdd::IRDI.parse(raw.to_s)
      end

      # Symbol type (:class, :property, ...) or +nil+.
      def entity_type
        @data["entity_type"]&.to_sym
      end

      # Meta-class IRDI code (e.g. "MDC_C002"), or +nil+ if the
      # type isn't registered.
      def meta_class_code
        Opencdd::MetaClasses.meta_class_for_type(entity_type)
      end

      # Name of the per-version subfolder that holds the current
      # version's XLS exports. +nil+ for flat-layout manifests.
      def current_version_dir
        @data["current_version_dir"]
      end

      # Version history compiled from the +versions+ array.
      # Empty when no versions are listed.
      def version_history
        vh = Opencdd::Entity::VersionHistory.new
        Array(@data["versions"]).each do |v|
          vh.attach(build_entry(v))
        end
        vh
      end

      def versions_empty?
        Array(@data["versions"]).empty?
      end

      # Constructs a minimal stub entity from this manifest, so
      # cross-references to entities that weren't loaded from a
      # +.xls+ still resolve. Returns +nil+ if the manifest lacks
      # an IRDI, type, or known meta-class.
      def to_stub_entity
        return nil unless irdi && meta_class_code
        meta_class = Opencdd::MetaClasses.for(meta_class_code)
        return nil unless meta_class&.entity_class

        code_property_id = Opencdd::MetaClasses.code_property_id_for(meta_class_code)
        props = code_property_id ? { code_property_id => @data["irdi"].to_s } : {}
        meta_class.entity_class.new(
          irdi: irdi,
          properties: props,
          meta_class_irdi: Opencdd::IRDI.parse(meta_class_code),
        )
      end

      private

      def build_entry(raw)
        Opencdd::Entity::VersionHistory::Entry.new(
          version:           raw["version"],
          revision:          raw["revision"],
          status:            raw["status"],
          timestamp:         raw["timestamp"],
          user:              raw["user"],
          change_request_id: raw["change_request_id"],
          unid:              raw["unid"],
          is_current:        raw["is_current"],
        )
      end
    end
  end
end
