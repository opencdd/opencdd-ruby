# frozen_string_literal: true

module Opencdd
  module Parcel
    # Walks a sharded downloads directory and collects every IRDI
    # referenced by a class .xls that points to a non-class entity
    # (property, unit, value-list, value-term). The output manifest
    # drives the per-entity scraper Pass 2 — see
    # +TODO.cdd-editor/43-scraper-pass-2-per-entity.md+.
    #
    # Source columns on the CLASS .xls (parsed by +Opencdd::Klass+):
    #   applicable_property_irdis   (MDC_P014) → property
    #   imported_property_irdis     (MDC_P090) → property (cross-dict)
    #   is_case_of_irdis            (MDC_P013) → class (cross-dict)
    #   sub_class_selection_irdis   (MDC_P016) → class
    #
    # Cross-dictionary IRDIs are partitioned by their source scheme so
    # the scraper can pick the right +Dictionary+ config. Properties
    # referenced in +applicable_property_irdis+ of a class in dict A
    # that point at dict B's IRDI space are emitted with
    # +source_scheme: B+.
    class ReferencedIrdis
      Entry = Struct.new(:irdi, :entity_type, :source_scheme, :referenced_by, keyword_init: true) do
        def to_h
          { irdi: irdi.to_s, entity_type: entity_type, source_scheme: source_scheme,
            referenced_by: referenced_by.dup }
        end
      end

      attr_reader :path

      def initialize(path)
        @path = path
      end

      # Returns +Hash{ source_scheme => Array<Entry> }+.
      def collect
        reader = Opencdd::Parcel::ShardedDirReader.new(@path)
        database = Opencdd::Database.new
        reader.load_into(database)

        by_irdi = {}
        database.classes.each do |klass|
          record_each(by_irdi, klass, klass.applicable_property_irdis, :property)
          record_each(by_irdi, klass, klass.imported_property_irdis,   :property)
          record_each(by_irdi, klass, klass.is_case_of_irdis,          :class)
          record_each(by_irdi, klass, klass.sub_class_selection_irdis, :class)
        end

        by_scheme = {}
        by_irdi.each_value do |entry|
          bucket = by_scheme[entry.source_scheme] ||= []
          bucket << entry
        end
        by_scheme.transform_values { |entries| entries.sort_by { |e| e.irdi.to_s } }
      end

      def as_json
        collect.transform_values { |entries| entries.map(&:to_h) }
      end

      def to_json(*args)
        require "json"
        JSON.pretty_generate(as_json, *args)
      end

      private

      def record_each(acc, klass, irdis, entity_type)
        Array(irdis).each do |raw|
          irdi = Opencdd::IRDI.parse(raw.to_s)
          next unless irdi
          scheme = irdi.scheme
          next unless scheme
          full = irdi.to_s
          entry = acc[full]
          if entry
            entry.referenced_by << klass.irdi.to_s unless entry.referenced_by.include?(klass.irdi.to_s)
          else
            acc[full] = Entry.new(
              irdi: irdi,
              entity_type: entity_type,
              source_scheme: scheme,
              referenced_by: [klass.irdi.to_s],
            )
          end
        end
      end
    end
  end
end
