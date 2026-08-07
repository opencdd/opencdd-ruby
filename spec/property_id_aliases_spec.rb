# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::PropertyIds, "alias registry integrity" do
  # Regression guard for the alias-collision audit (TODO.complete/1).
  # The audit (item A6 in data-private/TODO.full-cdd/17) flagged a
  # hypothetical collision where two REGISTRY entries share an alias
  # and `alias_map` silently keeps whichever was inserted last. As of
  # this snapshot, no such collision exists in the REGISTRY. This
  # spec pins that invariant so a future regression is caught at
  # spec time, not at runtime.

  describe ".alias_map — no alias is claimed by multiple IDs" do
    it "does not allow two REGISTRY entries to share an alias" do
      collisions = {}
      Opencdd::PropertyIds::REGISTRY.values.each do |entry|
        entry.aliases.each do |a|
          collisions[a] ||= []
          collisions[a] << entry.id unless collisions[a].include?(entry.id)
        end
      end
      shared = collisions.select { |_, ids| ids.size > 1 }
      expect(shared).to be_empty,
                        "aliases claimed by multiple REGISTRY IDs: #{shared.inspect}"
    end
  end

  describe ".canonical_id — resolves every alias to exactly one ID" do
    it "resolves 'symbol' to MDC_P025_1 (the IEC 61360 canonical)" do
      # MDC_P025_1 owns `symbol`, `preferred_symbol_text`, `symbol_in_text`.
      # If another entry (e.g. MDC_P021 or MDC_P023) ever tries to claim
      # `symbol`, the collision spec above will catch it first; this
      # assertion documents the intended resolution.
      expect(Opencdd::PropertyIds.canonical_id("symbol")).to eq("MDC_P025_1")
    end

    it "resolves 'unit_symbol' to MDC_P023" do
      expect(Opencdd::PropertyIds.canonical_id("unit_symbol")).to eq("MDC_P023")
    end

    it "resolves 'unit_structure' to MDC_P023" do
      expect(Opencdd::PropertyIds.canonical_id("unit_structure")).to eq("MDC_P023")
    end

    it "resolves 'definition_class' to MDC_P021" do
      expect(Opencdd::PropertyIds.canonical_id("definition_class")).to eq("MDC_P021")
    end
  end

  describe ".canonical_id — passes canonical IDs through unchanged" do
    it "returns MDC_P021 unchanged" do
      expect(Opencdd::PropertyIds.canonical_id("MDC_P021")).to eq("MDC_P021")
    end

    it "returns MDC_P023 unchanged" do
      expect(Opencdd::PropertyIds.canonical_id("MDC_P023")).to eq("MDC_P023")
    end

    it "returns MDC_P025_1 unchanged" do
      expect(Opencdd::PropertyIds.canonical_id("MDC_P025_1")).to eq("MDC_P025_1")
    end
  end
end