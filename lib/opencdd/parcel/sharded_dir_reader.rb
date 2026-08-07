# frozen_string_literal: true

module Opencdd
  module Parcel
    # Reads the per-class sharded Parcel layout emitted by cdd.iec.ch
    # downloads: a top-level directory containing one subdir per
    # class code, each subdir holding 1-6 +export_*_<code>.xls+
    # files (CLASS, PROPERTY, RELATION, UNIT, VALUELIST, VALUETERMS).
    #
    # Two on-disk layouts are supported:
    #
    # [flat (legacy)]   +<CODE>/export_*.xls+ directly under the code dir.
    # [per-version]     +<CODE>/<UNID>/export_*.xls+ nested under the
    #   current version's UNID, with +<CODE>/_entity.json+ identifying
    #   which +<UNID>+ folder is the current version. Emitted by
    #   +harvest/download_versions.py+.
    #
    # The reader is a thin orchestrator over three deep modules:
    #
    #   - +Opencdd::Parcel::LayoutDetector+ — single source of truth
    #     for "is this a class-code dir? where do the XLS live?"
    #   - +Opencdd::Parcel::EntityManifest+ — parses the
    #     +_entity.json+ sidecar and produces VersionHistory /
    #     stub entities.
    #   - +Opencdd::Parcel::FlatDirReader+ — actually reads the
    #     +.xls+ files into a Workbook.
    #
    # Example:
    #   reader = Opencdd::Parcel::ShardedDirReader.new("downloads/iec-63213")
    #   db = Opencdd::Database.new
    #   reader.load_into(db)
    #
    class ShardedDirReader
      # Detection patterns owned by Opencdd::Parcel::LayoutDetector
      # (SSOT). Aliased here for back-compat with external callers
      # that reference these constants by class.
      CLASS_CODE_PATTERN = Opencdd::Parcel::LayoutDetector::CLASS_CODE_PATTERN
      UNID_PATTERN       = Opencdd::Parcel::LayoutDetector::UNID_PATTERN

      attr_reader :path

      def initialize(path)
        @path = path
      end

      def load_into(database)
        class_subdirs.each do |subdir|
          active = active_xls_dir(subdir)
          next unless active
          workbook = Opencdd::Parcel::FlatDirReader.new(active).read_workbook
          database.add_workbook(workbook)
        end
        attach_unloaded_entities(database)
        attach_version_histories(database)
        database.finalize!
        database
      end

      # Walks each class subdir's +_entity.json+ and attaches its
      # +versions+ array to the corresponding entity.
      def attach_version_histories(database)
        class_subdirs.each do |subdir|
          manifest = Opencdd::Parcel::EntityManifest.read(subdir)
          next unless manifest
          next if manifest.versions_empty?
          target = database.find_by_code(File.basename(subdir))
          target&.attach_version_history(manifest.version_history)
        end
      end

      # Back-compat: external callers may reach the per-class version
      # history directly. New code should use EntityManifest.
      def parse_version_history(code_dir)
        manifest = Opencdd::Parcel::EntityManifest.read(code_dir)
        manifest&.version_history || Opencdd::Entity::VersionHistory.new
      end

      # Scans +_entities/+ for manifests whose entity wasn't loaded
      # by the XLS round (e.g. a property whose .xls export only had
      # CLASS rows). Creates minimal stub entities so cross-references
      # resolve.
      def attach_unloaded_entities(database)
        entities_root = File.join(@path, "_entities")
        return unless File.directory?(entities_root)

        Dir.children(entities_root).sort.each do |code|
          entity_dir = File.join(entities_root, code)
          next unless File.directory?(entity_dir)

          manifest = Opencdd::Parcel::EntityManifest.read(entity_dir)
          next unless manifest

          irdi = manifest.irdi
          next unless irdi
          next if database.find(irdi)

          stub = manifest.to_stub_entity
          database.add_entity(stub) if stub
        end
      end

      def read_workbook
        sub_workbooks = class_subdirs.filter_map do |subdir|
          active = active_xls_dir(subdir)
          next nil unless active
          Opencdd::Parcel::FlatDirReader.new(active).read_workbook
        end

        Opencdd::Parcel::Workbook.new(
          sheets: sub_workbooks.flat_map(&:sheets),
          sheetmap: sub_workbooks.flat_map(&:sheetmap),
          project: sub_workbooks.first&.project,
          source_path: @path.to_s,
        )
      end

      def class_subdirs
        return [] unless File.directory?(@path)
        dirs = list_class_subdirs(@path)

        # Also scan _entities/ for manifest-driven entity dirs.
        entities_root = File.join(@path, "_entities")
        dirs.concat(list_class_subdirs(entities_root)) if File.directory?(entities_root)

        dirs
      end

      # Delegates to LayoutDetector — single source of truth for
      # "where do the active XLS files live for this class-code dir?"
      def active_xls_dir(code_dir)
        Opencdd::Parcel::LayoutDetector.active_xls_dir(code_dir)
      end

      private

      def list_class_subdirs(root)
        Dir.children(root).sort
           .map { |n| File.join(root, n) }
           .select { |p| File.directory?(p) && Opencdd::Parcel::LayoutDetector.class_code?(File.basename(p)) }
      end

      def looks_like_class_code?(name)
        Opencdd::Parcel::LayoutDetector.class_code?(name)
      end

      def legacy?(filename)
        Opencdd::Parcel::LayoutDetector.legacy_export?(filename)
      end
    end
  end
end
