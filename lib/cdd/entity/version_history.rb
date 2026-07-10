# frozen_string_literal: true

module Cdd
  class Entity
    # Model object for the per-version provenance captured in
    # +downloads/<dict>/<CODE>/_entity.json#versions+. Each entry
    # represents one historical version of the entity: which version
    # and revision it was, its status at that point, who committed it,
    # and the change-request ID.
    #
    # The ShardedDirReader parses +_entity.json+ for each class subdir
    # and attaches a VersionHistory to every entity it creates. The
    # Json exporter then emits it as an array of version entries,
    # matching the IEC CDD "Version history" section on detail pages.
    class VersionHistory
      Entry = Struct.new(
        :version, :revision, :status, :timestamp, :user,
        :change_request_id, :unid, :is_current,
        keyword_init: true,
      ) do
        def current? = !!is_current
      end

      include Enumerable

      def initialize(entries = [])
        @entries = Array(entries)
      end

      attr_reader :entries

      def each(&block)
        @entries.each(&block)
      end

      def size
        @entries.size
      end

      def empty?
        @entries.empty?
      end

      def current
        @entries.find(&:current?) || @entries.first
      end

      def previous
        @entries.reject { |e| e == current }
      end

      def to_a
        @entries.dup
      end

      def attach(entry)
        @entries << entry
        self
      end
    end
  end
end
