# frozen_string_literal: true

module Opencdd
  module Parcel
    # Single source of truth for Parcel on-disk layout detection.
    #
    # Three layouts exist in the wild:
    #
    # [legacy single]   one <code>export_*.xls</code> file per type
    #                   (CLASS, PROPERTY, RELATION, UNIT, VALUELIST,
    #                   VALUETERMS).
    # [flat dir]        a directory containing those six files at the
    #                   top level.
    # [sharded dir]     a directory containing one subdir per class
    #                   code, each subdir holding 1-6 +export_*.xls+
    #                   files either directly (flat sharded) or under
    #                   a UNID-named version subfolder (per-version
    #                   sharded, identified by <code>_entity.json</code>).
    #
    # Previously <code>Reader</code>, <code>FlatDirReader</code>,
    # <code>ShardedDirReader</code>, and <code>ScrapeVerifier</code>
    # each held their own copies of the regexes and detection
    # helpers. Layout drift meant patching N files. Now they all
    # delegate here.
    module LayoutDetector
      # Class-code shape per IEC CDD conventions: 2-6 uppercase
      # letters, 1-6 digits, optional alnum suffix.
      CLASS_CODE_PATTERN = /\A[A-Z]{2,6}[0-9]{1,6}[A-Z0-9-]*\z/.freeze

      # Harvester per-version subfolder name (Lotus Notes UNID).
      UNID_PATTERN = /\A[0-9A-F]{32}\z/i.freeze

      # Per-type export filename produced by cdd.iec.ch's download
      # endpoint.
      FILE_PATTERN = /\Aexport_(CLASS|PROPERTY|RELATION|UNIT|VALUELIST|VALUETERMS)_[^\.]+\.(xls|xlsx)\z/i.freeze

      module_function

      # True if +name+ looks like a class code (AAA001, UAC696, ...).
      def class_code?(name)
        return false if name.nil?
        name.match?(CLASS_CODE_PATTERN)
      end

      # True if +filename+ is one of the harvester's export_* files.
      def legacy_export?(filename)
        return false if filename.nil?
        filename.match?(FILE_PATTERN)
      end

      # True if +name+ is a UNID-named subfolder.
      def unid?(name)
        return false if name.nil?
        name.match?(UNID_PATTERN)
      end

      # Returns the directory holding the active +export_*.xls+ files
      # for a given class-code dir, or +nil+ when no XLS is present.
      #
      # Resolution order:
      #   1. Per-version: +_entity.json+ names a UNID subfolder.
      #   2. Per-version (no manifest): a single UNID subfolder with XLS.
      #   3. Flat sharded: XLS files directly under +code_dir+.
      def active_xls_dir(code_dir)
        return nil unless File.directory?(code_dir)

        # Per-version with manifest.
        manifest = File.join(code_dir, "_entity.json")
        if File.file?(manifest)
          current = read_current_version_dir(manifest)
          if current && unid?(current)
            candidate = File.join(code_dir, current)
            return candidate if File.directory?(candidate)
          end
        end

        # Per-version without manifest: unique UNID subfolder with XLS.
        unid_subdirs = Dir.children(code_dir)
                          .select { |n| unid?(n) }
                          .map { |n| File.join(code_dir, n) }
                          .select { |p| File.directory?(p) }
        if unid_subdirs.size == 1
          active = unid_subdirs.first
          return active if Dir.children(active).any? { |f| legacy_export?(f) }
        end

        # Flat sharded.
        return code_dir if Dir.children(code_dir).any? { |f| legacy_export?(f) }

        nil
      end

      # True if +path+ is a sharded class-code subdir (contains XLS
      # directly or via the per-version layout).
      def sharded_class_subdir?(path)
        return false unless File.directory?(path)
        return false unless class_code?(File.basename(path))
        !active_xls_dir(path).nil?
      end

      # ── Internal ─────────────────────────────────────────────

      def read_current_version_dir(manifest_path)
        require "json"
        data = JSON.parse(File.read(manifest_path))
        data["current_version_dir"]
      rescue JSON::ParserError
        nil
      rescue Errno::ENOENT
        nil
      end
      private_class_method :read_current_version_dir
    end
  end
end
