# frozen_string_literal: true

require "json"

module Cdd
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
    # The reader walks the dictionary root, resolves each class subdir
    # to its "active xls dir" (current version folder for per-version
    # layout, the code dir itself for flat layout), then merges the
    # resulting workbooks into one +Cdd::Database+. This is the format
    # used in +downloads/<dict>/+ for IEC 61360, IEC 61987, IEC 63213,
    # IEC 63508, etc.
    #
    # Example:
    #   reader = Cdd::Parcel::ShardedDirReader.new("downloads/iec63213")
    #   db = Cdd::Database.new
    #   reader.load_into(db)
    #
    class ShardedDirReader
      CLASS_CODE_PATTERN = /\A[A-Z]{2,6}[0-9]{1,6}([A-Z0-9-]*)\z/
      UNID_PATTERN       = /\A[0-9A-F]{32}\z/i

      attr_reader :path

      def initialize(path)
        @path = path
      end

      def load_into(database)
        class_subdirs.each do |subdir|
          active = active_xls_dir(subdir)
          next unless active
          legacy = Cdd::Parcel::FlatDirReader.new(active)
          workbook = legacy.read_workbook
          database.add_workbook(workbook)
        end
        database.finalize!
        database
      end

      def read_workbook
        sub_workbooks = class_subdirs.filter_map do |subdir|
          active = active_xls_dir(subdir)
          next nil unless active
          Cdd::Parcel::FlatDirReader.new(active).read_workbook
        end

        Cdd::Parcel::Workbook.new(
          sheets: sub_workbooks.flat_map(&:sheets),
          sheetmap: sub_workbooks.flat_map(&:sheetmap),
          project: sub_workbooks.first&.project,
          source_path: @path.to_s,
        )
      end

      def class_subdirs
        return [] unless File.directory?(@path)
        Dir.children(@path).sort
          .map { |n| File.join(@path, n) }
          .select { |p| File.directory?(p) && looks_like_class_code?(File.basename(p)) }
      end

      # Returns the directory that holds the active +export_*.xls+ for
      # +code_dir+ — either the per-version UNID subfolder or the code
      # dir itself (legacy flat layout). Returns +nil+ when no XLS is
      # present (e.g. an entity whose scrape failed).
      def active_xls_dir(code_dir)
        return code_dir unless File.directory?(code_dir)

        # Per-version layout: trust _entity.json's current_version_dir
        # when it points at a real UNID subfolder.
        entity_idx = File.join(code_dir, "_entity.json")
        if File.file?(entity_idx)
          begin
            data = JSON.parse(File.read(entity_idx))
            current = data["current_version_dir"]
            if current && current =~ UNID_PATTERN
              candidate = File.join(code_dir, current)
              return candidate if File.directory?(candidate)
            end
          rescue JSON::ParserError
            # fall through to discovery
          end
        end

        # Per-version layout without _entity.json: pick the unique
        # UNID-named subdir that contains at least one export_*.xls.
        unid_subdirs = Dir.children(code_dir)
          .select { |n| n =~ UNID_PATTERN }
          .map { |n| File.join(code_dir, n) }
          .select { |p| File.directory?(p) }
        if unid_subdirs.size == 1
          active = unid_subdirs.first
          return active if Dir.children(active).any? { |f| legacy?(f) }
        end

        # Legacy flat layout: XLS files sit directly under the code dir.
        code_dir if Dir.children(code_dir).any? { |f| legacy?(f) }
      end

      private

      def looks_like_class_code?(name)
        name.match?(CLASS_CODE_PATTERN)
      end

      def legacy?(filename)
        filename =~ /\Aexport_(CLASS|PROPERTY|RELATION|UNIT|VALUELIST|VALUETERMS)_[^\.]+\.(xls|xlsx)\z/i
      end
    end
  end
end
