# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::PropertyIds do
  describe ".entry" do
    it "returns the Entry for a known property id" do
      entry = described_class.entry("MDC_P010")
      expect(entry.id).to eq("MDC_P010")
      expect(entry.aliases).to include("superclass")
      expect(entry.applies_to).to eq(:class)
    end

    it "returns nil for an unknown property id" do
      expect(described_class.entry("MDC_P999")).to be_nil
    end
  end

  describe ".canonical_id" do
    it "resolves a known alias to its canonical property id" do
      expect(described_class.canonical_id("superclass")).to eq("MDC_P010")
      expect(described_class.canonical_id("data_type")).to eq("MDC_P022")
      expect(described_class.canonical_id("condition")).to eq("MDC_P028")
      expect(described_class.canonical_id("symbol")).to eq("MDC_P025_1")
      expect(described_class.canonical_id("unit_symbol")).to eq("MDC_P023")
    end

    it "returns the input unchanged when it is already a canonical property id" do
      expect(described_class.canonical_id("MDC_P010")).to eq("MDC_P010")
    end

    it "returns the input unchanged when no alias matches" do
      expect(described_class.canonical_id("does_not_exist")).to be_nil
    end
  end

  describe ".multilingual?" do
    it "is true for preferred_name, definition, note, remark" do
      expect(described_class.multilingual?("MDC_P004")).to be(true)
      expect(described_class.multilingual?("MDC_P006")).to be(true)
    end

    it "is false for code, version, dates" do
      expect(described_class.multilingual?("MDC_P001_5")).to be(false)
      expect(described_class.multilingual?("MDC_P003_1")).to be(false)
    end

    it "is false for unknown ids" do
      expect(described_class.multilingual?("MDC_P999")).to be(false)
    end
  end

  describe ".normalize" do
    it "strips whitespace" do
      expect(described_class.normalize("  MDC_P010  ")).to eq("MDC_P010")
    end

    it "returns nil for nil and empty input" do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize("")).to be_nil
      expect(described_class.normalize("   ")).to be_nil
    end

    it "preserves language tags" do
      expect(described_class.normalize("preferred_name.en")).to eq("MDC_P004.en")
    end
  end

  describe ".alias_map" do
    it "is frozen and memoized" do
      first = described_class.alias_map
      second = described_class.alias_map
      expect(first).to equal(second)
      expect(first).to be_frozen
    end

    it "maps every alias to a canonical property id present in REGISTRY" do
      described_class.alias_map.each do |alias_name, property_id|
        expect(described_class.entry(property_id)).not_to be_nil
        expect(described_class.entry(property_id).aliases).to include(alias_name)
      end
    end

    it "has no duplicate aliases across entries" do
      tally = described_class::REGISTRY.flat_map { |_, e| e.aliases }.tally
      duplicates = tally.select { |_, count| count > 1 }
      expect(duplicates).to be_empty
    end
  end

  describe ".all_ids" do
    it "returns the full registry key set" do
      ids = described_class.all_ids
      expect(ids).to include("MDC_P001_5", "MDC_P010", "MDC_P014", "MDC_P044")
      expect(ids).to be_frozen
    end
  end

  describe "registry constants" do
    it "exposes every registry key as a constant equal to its id string" do
      described_class::REGISTRY.each_key do |id|
        expect(described_class.const_get(id)).to eq(id)
      end
    end

    it "includes the previously-hardcoded variant ids" do
      expect(described_class::MDC_P010_1).to eq("MDC_P010_1")
      expect(described_class::MDC_P004_1).to eq("MDC_P004_1")
      expect(described_class::MDC_P018_1).to eq("MDC_P018_1")
      expect(described_class::MDC_P023_1).to eq("MDC_P023_1")
      expect(described_class::MDC_P026).to eq("MDC_P026")
      expect(described_class::MDC_P206).to eq("MDC_P206")
      expect(described_class::EXT_P001).to eq("EXT_P001")
    end

    it "covers every allowed_property_id declared by MetaClasses" do
      declared = Cdd::MetaClass::MetaClasses.all.flat_map(&:allowed_property_ids).uniq
      registered = described_class::REGISTRY.keys
      expect(registered).to include(*declared)
    end
  end
end
