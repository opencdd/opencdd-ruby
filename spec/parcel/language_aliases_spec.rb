# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Parcel::LanguageAliases do
  describe ".normalize" do
    it "passes through ISO 639-1 codes unchanged" do
      expect(described_class.normalize("en")).to eq("en")
      expect(described_class.normalize("ja")).to eq("ja")
      expect(described_class.normalize("de")).to eq("de")
    end

    it "maps jp to ja (IEC CDD non-conformant)" do
      expect(described_class.normalize("jp")).to eq("ja")
    end

    it "handles nil and empty gracefully" do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize("")).to eq("")
    end

    it "strips surrounding whitespace" do
      expect(described_class.normalize("  en  ")).to eq("en")
      expect(described_class.normalize(" jp ")).to eq("ja")
    end

    it "is a pure function — does not warn or emit any side effect" do
      expect { described_class.normalize("jp") }.not_to output.to_stderr
    end

    it "is idempotent — normalizing an already-normalized code is a no-op" do
      first = described_class.normalize("jp")
      second = described_class.normalize(first)
      expect(second).to eq(first)
    end
  end

  describe ".alias?" do
    it "is true for codes in the alias table" do
      expect(described_class.alias?("jp")).to be(true)
    end

    it "is false for ISO 639-1 codes" do
      expect(described_class.alias?("en")).to be(false)
      expect(described_class.alias?("ja")).to be(false)
    end

    it "is false for nil and empty" do
      expect(described_class.alias?(nil)).to be(false)
      expect(described_class.alias?("")).to be(false)
    end
  end

  describe "ALIASES" do
    it "is frozen" do
      expect(described_class::ALIASES).to be_frozen
    end

    it "maps every key to an ISO 639-1 value" do
      described_class::ALIASES.each do |original, normalized|
        expect(original).to match(/\A[a-z]{2}\z/)
        expect(normalized).to match(/\A[a-z]{2}\z/)
        expect(original).not_to eq(normalized)
      end
    end
  end
end