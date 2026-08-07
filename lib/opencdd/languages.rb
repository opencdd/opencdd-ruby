# frozen_string_literal: true

module Opencdd
  # Value object representing the language configuration of a CDD
  # dictionary. The source language is the one the data was originally
  # authored in; translation languages are additional languages that
  # appear in the .xls property keys (e.g. +MDC_P004.de+).
  #
  # The exporter scans each entity's +@properties+ hash for
  # +<property_id>.<lang>+ keys to build per-field language maps
  # (TODO.work/08). This class is the model object that aggregates
  # "what languages does this dictionary have?" — used by the browser
  # to render a language switcher and by the data pipeline to report
  # language coverage.
  class Languages
    # IEC CDD source .xls files sometimes use non-standard language
    # codes that diverge from ISO 639-1. Map them here so the entire
    # ecosystem (gem, JSON wire format, browser CSS, TS model) speaks
    # the same ISO code. When a non-conformant code is encountered,
    # +normalize+ emits a one-line warning on stderr so data-quality
    # issues are visible without silently rewriting.
    LANG_ALIASES = {
      "jp" => "ja",
    }.freeze

    attr_reader :source, :translations

    def initialize(source: "en", translations: [])
      @source = self.class.normalize(source)
      @translations = Array(translations).map { |t| self.class.normalize(t) }.uniq - [@source]
      freeze
    end

    def all
      [@source] + @translations
    end

    def include?(lang)
      all.include?(self.class.normalize(lang))
    end

    def empty?
      @source.nil? || @source.empty?
    end

    def size
      all.size
    end

    def to_a
      all
    end

    def ==(other)
      other.is_a?(Opencdd::Languages) && source == other.source &&
        translations == other.translations
    end
    alias_method :eql?, :==

    def hash
      [source, translations].hash
    end

    # Normalize a language code to ISO 639-1.
    #
    # Returns the input unchanged if it is already standard. If the
    # code is a known non-conformant alias (e.g. "jp" from IEC CDD
    # source .xls), returns the ISO equivalent ("ja") and emits a
    # warning on stderr so the data-quality issue is visible.
    def self.normalize(lang)
      return lang if lang.nil?
      code = lang.to_s.strip
      return code if code.empty?
      if LANG_ALIASES.key?(code)
        warn "[opencdd] non-conformant language code #{code.inspect} → #{LANG_ALIASES[code].inspect} (ISO 639-1)"
        return LANG_ALIASES[code]
      end
      code
    end

    # Scan a properties hash for +<property_id>.<lang>+ keys and
    # return a Languages object covering every language seen. The
    # source language defaults to +default_source+ when no explicit
    # source-language key is present.
    def self.from_properties(properties, default_source: "en")
      langs = properties.keys.each_with_object(Set.new) do |key, acc|
        next unless key.include?(".")
        prefix, lang = key.split(".", 2)
        next unless lang =~ /\A[a-z]{2}(-[a-z0-9]+)?\z/i
        acc << normalize(lang)
      end
      source = langs.include?(default_source) ? default_source : (langs.first || default_source)
      translations = langs.to_a - [source]
      new(source: source, translations: translations)
    end
  end
end
