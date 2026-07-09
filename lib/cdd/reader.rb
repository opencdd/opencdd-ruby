# frozen_string_literal: true

module Cdd
  class Reader
    XLSX_EXTENSIONS = %w[.xlsx .xlsm .xltx].freeze
    SHARDED_CLASS_CODE = /\A[A-Z]{2,6}[0-9]{1,6}([A-Z0-9-]*)\z/
    UNID_PATTERN       = /\A[0-9A-F]{32}\z/i
    LEGACY_XLS_RE      = /\Aexport_(CLASS|PROPERTY|RELATION|UNIT|VALUELIST|VALUETERMS)_[^\.]+\.(xls|xlsx)\z/i

    class << self
      def load_database(path)
        new(path).load
      end

      def detect(path)
        case File.basename(path)
        when LEGACY_XLS_RE then :legacy_single
        else
          if File.directory?(path)
            children = Dir.children(path)
            if children.any? { |f| f =~ LEGACY_XLS_RE }
              :legacy_dir
            elsif children.any? { |f| sharded_class_subdir?(File.join(path, f)) }
              :sharded_dir
            else
              :unknown_dir
            end
          elsif XLSX_EXTENSIONS.include?(File.extname(path).downcase)
            :xlsx
          elsif File.extname(path).downcase == ".xls"
            :legacy_single
          else
            :unknown
          end
        end
      end
    end

    # A class-code subdir is "sharded" if it contains export_*.xls
    # directly (legacy flat layout) OR exposes the per-version layout
    # (+_entity.json+ pointing at a UNID subfolder, or a single UNID
    # subfolder holding export_*.xls).
    def self.sharded_class_subdir?(path)
      return false unless File.directory?(path)
      return false unless File.basename(path) =~ SHARDED_CLASS_CODE

      children = Dir.children(path)
      return true if children.any? { |f| f =~ LEGACY_XLS_RE }

      # Per-version layout: _entity.json names a UNID subfolder.
      entity_idx = File.join(path, "_entity.json")
      if File.file?(entity_idx)
        require "json"
        begin
          data = JSON.parse(File.read(entity_idx))
          current = data["current_version_dir"]
          return true if current && current =~ UNID_PATTERN &&
                         File.directory?(File.join(path, current))
        rescue JSON::ParserError
          # fall through
        end
      end

      # Per-version layout without _entity.json: a UNID subfolder holds XLS.
      unid_subdirs = children.select { |n| n =~ UNID_PATTERN }
                              .map { |n| File.join(path, n) }
      unid_subdirs.any? do |p|
        File.directory?(p) && Dir.children(p).any? { |f| f =~ LEGACY_XLS_RE }
      end
    end

    attr_reader :path

    def initialize(path)
      @path = path
    end

    def load
      db = Cdd::Database.new
      load_into(db)
      db.finalize!
      db
    end

    def load_into(db)
      case Cdd::Reader.detect(@path)
      when :xlsx, :legacy_single
        Cdd::Parcel::WorkbookReader.new(@path).load_into(db)
      when :legacy_dir
        Cdd::Parcel::FlatDirReader.new(@path).load_into(db)
      when :sharded_dir
        Cdd::Parcel::ShardedDirReader.new(@path).load_into(db)
      else
        raise ArgumentError, "Cannot detect Parcel/Excel format at #{@path.inspect}"
      end
    end
  end
end
