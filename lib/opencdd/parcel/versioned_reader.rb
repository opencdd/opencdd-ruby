# frozen_string_literal: true

module Opencdd
  module Parcel
    # Reads historical versions of entities from a sharded
    # per-version Parcel layout.
    #
    # The sharded layout stores every version of an entity in a
    # per-UNID subfolder: +<entity_dir>/<UNID>/export_*.xls+. The
    # +_entity.json+ sidecar lists every version and which UNID is
    # current. ShardedDirReader reads only the current version;
    # VersionedReader exposes the full history.
    #
    # Delegates to:
    #   - +Opencdd::Parcel::EntityManifest+ for version metadata.
    #   - +Opencdd::Parcel::FlatDirReader+ for xls parsing of one
    #     version's subfolder.
    #
    # Example:
    #   reader = Opencdd::Parcel::VersionedReader.new("downloads/iec-63213")
    #   reader.versions_for("KEA012")    # => 3 VersionHistory::Entry
    #   reader.load_version("KEA012", "ABC123...") # => Database with v002 content
    class VersionedReader
      attr_reader :path

      def initialize(path)
        @path = path
      end

      # All versions recorded for +code+, as
      # +Opencdd::Entity::VersionHistory::Entry+ instances.
      # Empty +VersionHistory+ if +code+ has no manifest.
      def versions_for(code)
        manifest = manifest_for(code)
        return Opencdd::Entity::VersionHistory.new unless manifest
        manifest.version_history
      end

      # Load a single historical version's content as a standalone
      # Database. The +unid+ identifies which version's subfolder
      # to read.
      #
      # Returns +nil+ if the version subfolder doesn't exist or has
      # no +.xls+ files. The returned database is finalized but not
      # cross-linked to other entities (historical context only).
      def load_version(code, unid)
        version_dir = version_dir_for(code, unid)
        return nil unless version_dir && File.directory?(version_dir)
        return nil unless Dir.children(version_dir).any? { |f| Opencdd::Parcel::LayoutDetector.legacy_export?(f) }

        workbook = Opencdd::Parcel::FlatDirReader.new(version_dir).read_workbook
        database = Opencdd::Database.new
        database.add_workbook(workbook)
        attach_version_history(database, code)
        database.finalize!
        database
      end

      # The entity subdirectory for +code+. Tries both the legacy
      # +<path>/<code>+ layout and the manifest-driven
      # +<path>/_entities/<code>+ layout.
      def entity_dir_for(code)
        flat = File.join(@path, code)
        return flat if File.directory?(flat)
        sharded = File.join(@path, "_entities", code)
        return sharded if File.directory?(sharded)
        nil
      end

      private

      def manifest_for(code)
        dir = entity_dir_for(code)
        return nil unless dir
        Opencdd::Parcel::EntityManifest.read(dir)
      end

      def version_dir_for(code, unid)
        dir = entity_dir_for(code)
        return nil unless dir
        candidate = File.join(dir, unid)
        return candidate if File.directory?(candidate)
        nil
      end

      def attach_version_history(database, code)
        manifest = manifest_for(code)
        return unless manifest
        return if manifest.versions_empty?
        manifest.version_history.entries.each do |entry|
          next unless entry.unid
          target = database.find_by_code(code)
          target&.attach_version_history(manifest.version_history)
          break
        end
      end
    end
  end
end
