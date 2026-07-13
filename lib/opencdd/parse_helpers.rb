# frozen_string_literal: true

require "strscan"

# Legacy module. The canonical home for collection parsing is now
# +Opencdd::StructuredValues+ — see +unwrap_and_split+, +rejoin+,
# +parse_ref_set+, +parse_synonyms+. ParseHelpers remains as a
# thin back-compat layer for code that hasn't migrated yet (notably
# the +Entity+ mixin). Do not add new callers; prefer StructuredValues.
module Opencdd
  module ParseHelpers
    module_function

    # Delegates to StructuredValues — single source of truth for
    # brace/paren/comma handling. Whitespace-separated forms are a
    # Parcel-specific quirk preserved here for back-compat.
    def parse_irdi_list(raw)
      return [] if raw.nil? || raw.to_s.strip.empty?
      tokens = Opencdd::StructuredValues.unwrap_and_split(raw)
      # Some Parcel sources use whitespace as the separator inside
      # a single "set" cell. Honour both shapes.
      tokens.flat_map { |t| t.split(/\s+/) }.reject(&:empty?).filter_map do |t|
        Opencdd::IRDI.parse(t)
      end
    end

    def parse_string_list(raw)
      Opencdd::StructuredValues.unwrap_and_split(raw)
    end

    def parse_synonym_tuples(raw)
      return [] if raw.nil? || raw.to_s.strip.empty?
      Opencdd::StructuredValues.parse_synonyms(raw)
    end

    # Parses both the {(name,lang),...} structured form and the
    # legacy flat (lang, name, lang, name, ...) form. Kept on
    # ParseHelpers because the flat form isn't a synonym-specific
    # concept — it's an ad-hoc legacy wire shape.
    def parse_pair_list(raw)
      return [] if raw.nil? || raw.to_s.strip.empty?
      s = raw.to_s.strip
      return parse_synonym_tuples(s) if brace_wrapped?(s)
      return [[nil, s]] unless paren_wrapped?(s)
      unwrap_parens(s)
        .split(",")
        .each_slice(2)
        .map { |lang, name| [lang&.strip, name&.strip] }
    end

    # ── Thin legacy predicates (kept for back-compat) ──────────
    def unwrap_parens(s)
      s = s.to_s
      paren_wrapped?(s) ? s[1..-2] : s
    end

    def unwrap_delimiters(s)
      s = s.to_s
      return s[1..-2] if paren_wrapped?(s) || brace_wrapped?(s)
      s
    end

    def paren_wrapped?(s)
      s = s.to_s
      s.start_with?("(") && s.end_with?(")")
    end

    def brace_wrapped?(s)
      s = s.to_s
      s.start_with?("{") && s.end_with?("}")
    end
  end
end
