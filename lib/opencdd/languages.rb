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
  #
  # This is a model object. It does not normalize language codes:
  # source-format quirks (e.g. IEC CDD .xls files using "jp" for
  # Japanese) are normalized at the SheetSchema ingestion boundary
  # via +Opencdd::Parcel::LanguageAliases+, so every consumer of
  # this class can assume ISO 639-1 codes unconditionally.
  class Languages
    attr_reader :source, :translations

    def initialize(source: "en", translations: [])
      @source = source.to_s
      @translations = Array(translations).map(&:to_s).uniq - [@source]
      freeze
    end

    def all
      [@source] + @translations
    end

    def include?(lang)
      all.include?(lang.to_s)
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

    # Scan a properties hash for +<property_id>.<lang>+ keys and
    # return a Languages object covering every language seen. The
    # source language defaults to +default_source+ when no explicit
    # source-language key is present.
    def self.from_properties(properties, default_source: "en")
      langs = properties.keys.each_with_object(Set.new) do |key, acc|
        next unless key.include?(".")
        _, lang = key.split(".", 2)
        next unless lang =~ /\A[a-z]{2}(-[a-z0-9]+)?\z/i
        acc << lang
      end
      source = langs.include?(default_source) ? default_source : (langs.first || default_source)
      translations = langs.to_a - [source]
      new(source: source, translations: translations)
    end
  end
end