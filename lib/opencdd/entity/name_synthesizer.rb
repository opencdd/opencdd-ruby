# frozen_string_literal: true

module Opencdd
  class Entity
    # Reverse name-to-ID resolution for Parcel sheets that omit the
    # #PROPERTY_ID directive row. Some cdd.iec.ch export formats
    # (notably RELATION exports) include only #PROPERTY_NAME.en,
    # leaving the importer unable to map column positions to property
    # IDs. NameSynthesizer bridges that gap using the IEC 62656-1
    # defined column names.
    #
    # Extracted from SheetSchema so SheetSchema focuses on header
    # parsing + Column construction. Name synthesis is a separate
    # concern with its own test surface.
    #
    # The name→ID table itself lives in Opencdd::PropertyIds::IEC_COLUMN_NAMES
    # (the lint-exempt SSOT). NAME_TO_PROPERTY_ID is kept here as a
    # back-compat alias so existing callers see no public-API change.
    module NameSynthesizer
      NAME_TO_PROPERTY_ID = Opencdd::PropertyIds::IEC_COLUMN_NAMES

      # Given a PROPERTY_NAME directive row (Array of name strings),
      # returns a parallel Array of property IDs (or nil where the
      # name is unrecognized). Language suffixes (.EN, .FR) are
      # stripped for lookup and re-appended to the synthesized ID.
      #
      #   synthesize(["Code", "PreferredName.EN", "Unknown"])
      #   => ["MDC_P001_5", "MDC_P004.en", nil]
      def self.synthesize(name_values)
        Array.new(name_values.size) do |idx|
          val = name_values[idx]
          next nil if val.nil? || val.to_s.strip.empty?
          raw = val.to_s.strip
          if raw =~ /\A(.+)\.([A-Za-z]{2})\z/
            base = $1
            lang = $2
            pid = NAME_TO_PROPERTY_ID[base]
            pid ? "#{pid}.#{lang.downcase}" : nil
          else
            NAME_TO_PROPERTY_ID[raw]
          end
        end
      end
    end
  end
end
