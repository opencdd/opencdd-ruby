# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::PropertyDataTypeElement do
  describe "VALUES" do
    it "exposes the canonical set of DET codes" do
      expect(described_class::VALUES).to eq(%w[NON_DEPENDENT_P_DET CONDITION_DET DEPENDENT_P_DET])
      expect(described_class::VALUES).to be_frozen
    end
  end

  describe "#initialize" do
    it "upcases the input" do
      expect(described_class.new("non_dependent_p_det").value).to eq("NON_DEPENDENT_P_DET")
    end

    it "raises ArgumentError for unknown value" do
      expect { described_class.new("UNKNOWN") }.to raise_error(ArgumentError, /unknown property data element type/)
    end
  end

  describe ".parse" do
    it "parses canonical values case-insensitively" do
      expect(described_class.parse("condition_det")).to be_a(described_class)
    end

    it "returns nil for nil/empty input" do
      expect(described_class.parse(nil)).to be_nil
      expect(described_class.parse("")).to be_nil
    end

    it "returns nil for unknown values" do
      expect(described_class.parse("UNKNOWN")).to be_nil
    end
  end

  describe "predicates" do
    it "exposes non_dependent?, condition?, dependent?" do
      expect(described_class.new("NON_DEPENDENT_P_DET").non_dependent?).to be(true)
      expect(described_class.new("CONDITION_DET").condition?).to be(true)
      expect(described_class.new("DEPENDENT_P_DET").dependent?).to be(true)
    end

    it "exposes conditional? = condition? || dependent?" do
      expect(described_class.new("CONDITION_DET")).to be_conditional
      expect(described_class.new("DEPENDENT_P_DET")).to be_conditional
      expect(described_class.new("NON_DEPENDENT_P_DET")).not_to be_conditional
    end
  end

  describe "to_s and to_sym" do
    it "renders the canonical form" do
      det = described_class.new("non_dependent_p_det")
      expect(det.to_s).to eq("NON_DEPENDENT_P_DET")
      expect(det.to_sym).to eq(:non_dependent_p_det)
    end
  end

  describe "equality and hash" do
    it "treats identical values as equal regardless of input case" do
      a = described_class.new("NON_DEPENDENT_P_DET")
      b = described_class.new("non_dependent_p_det")
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end
  end
end
