# frozen_string_literal: true

module Cdd
  class Entity
    # Typed reader for field declarations. Knows how to extract a
    # value of a given kind from an entity's properties hash. The
    # single source of truth for "what does MDC_P004.en look like"
    # so the Json exporter, validators, and TS codegen all agree.
    module FieldReader
      class << self
        # Read the +name+ field from +entity+. Multilingual fields
        # accept a +lang:+ keyword and fall back to source-language
        # (stored under the bare `MDC_P###` key) when the requested
        # language is missing.
        def read(entity, name, lang: nil)
          entry = FieldRegistry.field_for(entity.class, name)
          return nil unless entry

          # Synthetic fields defined with a block: evaluate the block
          # in the entity's context via instance_exec. This preserves
          # access to private helper methods without using send to
          # bypass privacy (encapsulation rule from CLAUDE.md).
          return entity.instance_exec(&entry.block) if entry.block?

          # Legacy form: synthetic fields name a public reader method.
          # public_send is safe here because readers are public API.
          return entity.public_send(entry.reader) if entry.synthetic? && entry.reader

          raw =
            if entry.multilingual?
              raw_multilingual(entity, entry, lang)
            else
              entity.properties[entry.property_id]
            end

          coerce(raw, entry.value_kind)
        end

        private

        def raw_multilingual(entity, entry, lang)
          props = entity.properties
          # The scrape stores multilingual values under "<id>.<lang>"
          # (e.g. "MDC_P004.en", "MDC_P004.de"). Some legacy data
          # omits the suffix entirely ("MDC_P004" with no .en). When
          # no lang is requested, default to "en" — the historical
          # source language for all IEC CDD dictionaries.
          effective_lang = lang || "en"
          props["#{entry.property_id}.#{effective_lang}"] ||
            props[entry.property_id] ||
            props["#{entry.property_id}.en"]
        end

        # Convert +raw+ (a String from the .xls) into the typed
        # Ruby value the model expects. Collection kinds (:set_of_refs,
        # :synonym_pairs) return empty arrays for nil/blank input so
        # callers can safely iterate without nil checks — mirrors the
        # legacy hand-written accessors.
        def coerce(raw, value_kind)
          case value_kind
          when :string, :date, :date_time, :condition
            raw.nil? ? nil : raw.to_s
          when :irdi, :identifier_ref, :class_ref
            parse_irdi(raw)
          when :set_of_refs
            parse_irdi_list_via_helpers(raw)
          when :string_list
            parse_string_list_via_helpers(raw)
          when :synonym_pairs
            parse_pair_list_via_helpers(raw)
          when :integer
            raw.nil? ? nil : (Integer(raw) rescue raw)
          when :boolean
            raw.nil? ? nil : parse_boolean(raw)
          else
            raw
          end
        end

        def parse_irdi(raw)
          return nil if raw.to_s.strip.empty?
          Cdd::IRDI.parse(raw)
        rescue Cdd::IRDI::ParseError
          nil
        end

        # Parcel's set_of_refs and synonym_pairs wire shapes are
        # delimited with braces/parens and commas. Parsed inline
        # rather than via Cdd::ParseHelpers because ParseHelpers
        # methods are private (intended for mixin within Entity).
        def parse_irdi_list_via_helpers(raw)
          return [] if raw.to_s.strip.empty?
          stripped = raw.to_s.strip.sub(/\A[\{\(\[]+/, "").sub(/[\}\)\]]+\z/, "")
          stripped
            .split(/[,;\s]+/)
            .reject(&:empty?)
            .filter_map { |s| parse_irdi(s) }
        end

        def parse_pair_list_via_helpers(raw)
          return [] if raw.to_s.strip.empty?
          stripped = raw.to_s.strip.sub(/\A[\{\(\[]+/, "").sub(/[\}\)\]]+\z/, "")
          tokens = stripped.split(/[,;]+/).map(&:strip).reject(&:empty?)
          # Parcel synonym wire shape alternates lang, name, lang, name:
          # "(en, Foo, fr, Bidon)" → [["en", "Foo"], ["fr", "Bidon"]].
          # If a token contains ":", treat as explicit "lang:name" pair.
          # Otherwise group consecutive tokens into pairs.
          if tokens.any? { |t| t.include?(":") }
            tokens.map { |pair| parse_synonym_pair(pair) }.compact
          else
            tokens.each_slice(2).map { |a, b| b ? [a, b] : [nil, a] }
          end
        end

        def parse_string_list_via_helpers(raw)
          return [] if raw.to_s.strip.empty?
          stripped = raw.to_s.strip.sub(/\A[\{\(\[]+/, "").sub(/[\}\)\]]+\z/, "")
          stripped.split(/[,;]+/).map(&:strip).reject(&:empty?)
        end

        def parse_synonym_pair(pair)
          if pair.include?(":")
            lang, name = pair.split(":", 2).map(&:strip)
            [lang.empty? ? nil : lang, name]
          else
            [nil, pair]
          end
        end

        def parse_boolean(raw)
          return raw unless raw.is_a?(String)
          case raw.strip.downcase
          when "true", "1", "yes", "y" then true
          when "false", "0", "no", "n", "" then false
          else raw
          end
        end
      end
    end
  end
end
