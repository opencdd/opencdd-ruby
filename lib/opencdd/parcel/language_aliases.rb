# frozen_string_literal: true

module Opencdd
  module Parcel
    # Maps non-conformant language codes found in IEC CDD source .xls
    # exports to their ISO 639-1 equivalents.
    #
    # This is a Parcel-layer concern, not a model concern: the aliases
    # exist because one specific source format (IEC CDD XLS) uses
    # non-standard codes in its property ID suffixes and directive
    # rows. The +Languages+ value object — and every downstream
    # consumer (JSON wire format, browser, TS model) — speaks ISO
    # 639-1 unconditionally.
    #
    # The normalization happens at the SheetSchema ingestion
    # boundary so downstream code never sees an alias. SheetSchema
    # also exposes the set of original-to-canonical mappings it
    # applied via +#normalized_language_codes+ for data-quality
    # reporting.
    module LanguageAliases
      ALIASES = {
        "jp" => "ja",
      }.freeze

      # Returns the ISO 639-1 form of +code+, or the input unchanged
      # if it is already standard. Pure function: no I/O, no side
      # effects.
      def self.normalize(code)
        return code if code.nil?
        s = code.to_s.strip
        return s if s.empty?
        ALIASES.fetch(s, s)
      end

      # True when +code+ would be rewritten by +normalize+.
      def self.alias?(code)
        return false if code.nil?
        ALIASES.key?(code.to_s.strip)
      end
    end
  end
end