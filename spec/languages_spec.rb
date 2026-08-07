# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Languages do
  describe "construction" do
    it "sets source and translations" do
      langs = described_class.new(source: "en", translations: %w[fr ja])
      expect(langs.source).to eq("en")
      expect(langs.translations).to eq(%w[fr ja])
    end

    it "excludes source from translations" do
      langs = described_class.new(source: "en", translations: %w[en fr])
      expect(langs.translations).to eq(%w[fr])
    end

    it "deduplicates translations" do
      langs = described_class.new(source: "en", translations: %w[fr fr ja ja])
      expect(langs.translations).to eq(%w[fr ja])
    end

    it "freezes the instance" do
      langs = described_class.new(source: "en")
      expect(langs).to be_frozen
    end
  end

  describe "#all" do
    it "returns source first, then translations" do
      langs = described_class.new(source: "en", translations: %w[fr ja])
      expect(langs.all).to eq(%w[en fr ja])
    end
  end

  describe "#include?" do
    it "is true for the source language" do
      langs = described_class.new(source: "en", translations: %w[fr])
      expect(langs.include?("en")).to be(true)
    end

    it "is true for translation languages" do
      langs = described_class.new(source: "en", translations: %w[fr ja])
      expect(langs.include?("fr")).to be(true)
      expect(langs.include?("ja")).to be(true)
    end

    it "is false for absent languages" do
      langs = described_class.new(source: "en")
      expect(langs.include?("de")).to be(false)
    end
  end

  describe "#size" do
    it "counts source + translations" do
      expect(described_class.new(source: "en", translations: %w[fr ja]).size).to eq(3)
    end
  end

  describe "#empty?" do
    it "is false when source is present" do
      expect(described_class.new(source: "en")).not_to be_empty
    end

    it "is true when source is nil/empty" do
      expect(described_class.new(source: "")).to be_empty
      expect(described_class.new(source: nil)).to be_empty
    end
  end

  describe "#==" do
    it "is equal when source and translations match" do
      a = described_class.new(source: "en", translations: %w[fr])
      b = described_class.new(source: "en", translations: %w[fr])
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "is not equal when translations differ" do
      a = described_class.new(source: "en", translations: %w[fr])
      b = described_class.new(source: "en", translations: %w[de])
      expect(a).not_to eq(b)
    end
  end

  describe ".normalize" do
    it "passes through ISO 639-1 codes unchanged" do
      expect(described_class.normalize("en")).to eq("en")
      expect(described_class.normalize("ja")).to eq("ja")
      expect(described_class.normalize("de")).to eq("de")
    end

    it "maps jp to ja (IEC CDD non-conformant)" do
      expect(described_class.normalize("jp")).to eq("ja")
    end

    it "warns on stderr when a non-conformant code is seen" do
      expect { described_class.normalize("jp") }
        .to output(/non-conformant language code "jp"/).to_stderr
    end

    it "does not warn for standard codes" do
      expect { described_class.normalize("en") }.not_to output.to_stderr
    end

    it "handles nil and empty gracefully" do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize("")).to eq("")
    end

    it "strips whitespace" do
      expect(described_class.normalize("  en  ")).to eq("en")
    end
  end

  describe "normalization on construction" do
    it "normalizes source and translations" do
      langs = described_class.new(source: "en", translations: %w[jp fr])
      expect(langs.translations).to eq(%w[ja fr])
    end

    it "does not double-count jp and ja" do
      langs = described_class.new(source: "en", translations: %w[jp ja])
      expect(langs.translations).to eq(%w[ja])
    end
  end

  describe ".from_properties" do
    it "scans properties hash for language-tagged keys" do
      props = { "MDC_P004.en" => "Vehicle", "MDC_P004.fr" => "Véhicule", "MDC_P004.de" => "Fahrzeug" }
      langs = described_class.from_properties(props)
      expect(langs.source).to eq("en")
      expect(langs.translations.sort).to eq(%w[de fr])
    end

    it "defaults source to the first language when en is absent" do
      props = { "MDC_P004.fr" => "Véhicule", "MDC_P004.de" => "Fahrzeug" }
      langs = described_class.from_properties(props, default_source: "en")
      expect(langs.source).to eq("fr")
    end

    it "ignores non-language keys" do
      props = { "MDC_P004" => "Vehicle", "C016" => "Released" }
      langs = described_class.from_properties(props)
      expect(langs.all).to eq(%w[en])
    end

    it "normalizes non-conformant codes like jp to ja" do
      props = { "MDC_P004.en" => "Vehicle", "MDC_P004.jp" => "車両" }
      langs = described_class.from_properties(props)
      expect(langs.translations).to eq(%w[ja])
    end
  end
end
