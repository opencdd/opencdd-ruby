# frozen_string_literal: true

module Cdd
  class ValueList < Cdd::Entity
    LIST_TYPE_ALIASES = {
      "EXTENSIBLE" => :extensible,
      "CLOSED"     => :closed,
      "OPEN"       => :open,
    }.freeze

    # ── Pure field reads ─────────────────────────────────────────
    field :term_irdis, "MDC_P043"
    # MDC_P044 is :set_of_refs in REGISTRY but ValueList code_list is
    # a list of plain codes, not IRDIs. Use :string_list to preserve
    # historical behavior.
    field :code_list,  "MDC_P044", :string_list

    # ── Computed fields with custom readers ──────────────────────
    field :selection_count, synthetic: true, reader: :read_selection_count
    field :list_type,       synthetic: true, reader: :read_list_type

    def terms(database = nil)
      return enum_for(:terms) unless block_given?
      term_irdis.each do |i|
        if database
          term = database.find(i)
          yield term if term
        end
      end
    end

    private

    def read_selection_count
      raw = properties[Cdd::PropertyIds::MDC_P045]
      return nil unless raw
      s = raw.to_s.strip
      s = s[1..-2] if s.start_with?("(") && s.end_with?(")")
      parts = s.split(",").map { |x| Integer(x.strip) rescue nil }.compact
      parts.empty? ? nil : parts
    end

    def read_list_type
      raw = properties[Cdd::PropertyIds::MDC_P046]
      LIST_TYPE_ALIASES[raw] || raw
    end
  end
end
