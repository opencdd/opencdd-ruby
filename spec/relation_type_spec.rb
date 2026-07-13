# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::RelationType do
  describe "VALUES" do
    it "exposes the canonical set of relation type codes" do
      expect(described_class::VALUES).to eq(%w[
        PREDICATION FUNCTION ASSOCIATION AGGREGATION COMPOSITION
        GENERALIZATION SPECIALIZATION
      ])
      expect(described_class::VALUES).to be_frozen
    end
  end

  describe "#initialize" do
    it "upcases the input" do
      expect(described_class.new("predication").value).to eq("PREDICATION")
    end

    it "raises ArgumentError for unknown value" do
      expect { described_class.new("UNKNOWN") }.to raise_error(ArgumentError, /unknown relation type/)
    end
  end

  describe ".parse" do
    it "parses known values case-insensitively" do
      parsed = described_class.parse("function")
      expect(parsed).to be_a(described_class)
      expect(parsed.function?).to be(true)
    end

    it "returns nil for nil/empty input" do
      expect(described_class.parse(nil)).to be_nil
      expect(described_class.parse("")).to be_nil
    end

    it "returns nil for unknown values" do
      expect(described_class.parse("UNKNOWN")).to be_nil
    end
  end

  describe ".parse_or_symbol" do
    it "returns the RelationType for known values" do
      expect(described_class.parse_or_symbol("predication")).to be_a(described_class)
    end

    it "returns a symbol for unknown values" do
      expect(described_class.parse_or_symbol("LINKAGE")).to eq(:LINKAGE)
    end

    it "returns nil for nil/empty input" do
      expect(described_class.parse_or_symbol(nil)).to be_nil
      expect(described_class.parse_or_symbol("")).to be_nil
    end
  end

  describe "predicates" do
    it "exposes one predicate per value" do
      expect(described_class.new("PREDICATION").predication?).to    be(true)
      expect(described_class.new("FUNCTION").function?).to          be(true)
      expect(described_class.new("ASSOCIATION").association?).to    be(true)
      expect(described_class.new("AGGREGATION").aggregation?).to    be(true)
      expect(described_class.new("COMPOSITION").composition?).to    be(true)
      expect(described_class.new("GENERALIZATION").generalization?).to be(true)
      expect(described_class.new("SPECIALIZATION").specialization?).to be(true)
    end

    it "exposes #hierarchical?" do
      expect(described_class.new("GENERALIZATION")).to be_hierarchical
      expect(described_class.new("SPECIALIZATION")).to be_hierarchical
      expect(described_class.new("AGGREGATION")).to be_hierarchical
      expect(described_class.new("COMPOSITION")).to be_hierarchical
      expect(described_class.new("PREDICATION")).not_to be_hierarchical
      expect(described_class.new("FUNCTION")).not_to be_hierarchical
      expect(described_class.new("ASSOCIATION")).not_to be_hierarchical
    end
  end

  describe "to_s and to_sym" do
    it "renders the canonical form" do
      rt = described_class.new("predication")
      expect(rt.to_s).to eq("PREDICATION")
      expect(rt.to_sym).to eq(:predication)
    end
  end

  describe "equality and hash" do
    it "treats identical values as equal" do
      a = described_class.new("PREDICATION")
      b = described_class.new("predication")
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end
  end
end
