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
  end
end
