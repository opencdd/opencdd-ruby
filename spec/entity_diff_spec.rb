# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::EntityDiff do
  let(:irdi) { Opencdd::IRDI.parse("0112/2///TEST#AAA001") }

  def build_entity(properties)
    Opencdd::Klass.new(irdi: irdi, properties: properties)
  end

  describe ".between" do
    it "returns an EntityDiff instance" do
      diff = described_class.between(build_entity({}), build_entity({}))
      expect(diff).to be_a(described_class)
    end

    it "raises ArgumentError when IRDIs differ" do
      other = Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse("0112/2///TEST#AAA002"),
        properties: {},
      )
      expect {
        described_class.between(build_entity({}), other)
      }.to raise_error(ArgumentError, /same IRDI/)
    end
  end

  describe "#empty?" do
    it "is true for identical entities" do
      diff = described_class.between(
        build_entity("MDC_P001" => "X"),
        build_entity("MDC_P001" => "X"),
      )
      expect(diff).to be_empty
    end

    it "is false when any field differs" do
      diff = described_class.between(
        build_entity("MDC_P001" => "X"),
        build_entity("MDC_P001" => "Y"),
      )
      expect(diff).not_to be_empty
    end
  end

  describe "#added" do
    it "lists field names present in to_entity but not from_entity" do
      diff = described_class.between(
        build_entity("MDC_P001" => "X"),
        build_entity("MDC_P001" => "X", "MDC_P999" => "new"),
      )
      expect(diff.added).to eq(["MDC_P999"])
    end
  end

  describe "#removed" do
    it "lists field names present in from_entity but not to_entity" do
      diff = described_class.between(
        build_entity("MDC_P001" => "X", "MDC_P005" => "gone"),
        build_entity("MDC_P001" => "X"),
      )
      expect(diff.removed).to eq(["MDC_P005"])
    end
  end

  describe "#changed" do
    it "lists fields with different values" do
      diff = described_class.between(
        build_entity("MDC_P001" => "old"),
        build_entity("MDC_P001" => "new"),
      )
      expect(diff.changed.size).to eq(1)
      change = diff.changed.first
      expect(change.field).to eq("MDC_P001")
      expect(change.from).to eq("old")
      expect(change.to).to eq("new")
    end

    it "groups multilingual variants under their base field" do
      diff = described_class.between(
        build_entity("MDC_P001.en" => "Hello", "MDC_P001.fr" => "Bonjour"),
        build_entity("MDC_P001.en" => "Hi", "MDC_P001.fr" => "Bonjour"),
      )
      expect(diff.changed.size).to eq(1)
      expect(diff.changed.first.field).to eq("MDC_P001")
      expect(diff.changed.first.from).to eq("en" => "Hello", "fr" => "Bonjour")
      expect(diff.changed.first.to).to eq("en" => "Hi", "fr" => "Bonjour")
    end

    it "treats a newly added language as a change, not an addition" do
      diff = described_class.between(
        build_entity("MDC_P001.en" => "Hello"),
        build_entity("MDC_P001.en" => "Hello", "MDC_P001.fr" => "Bonjour"),
      )
      expect(diff.added).to eq([])
      expect(diff.changed.size).to eq(1)
    end
  end

  describe "#size" do
    it "returns the total change count" do
      diff = described_class.between(
        build_entity("MDC_P001" => "X", "MDC_P002" => "removed"),
        build_entity("MDC_P001" => "Y", "MDC_P003" => "added"),
      )
      expect(diff.size).to eq(3)
    end
  end

  describe "#to_h" do
    it "produces a JSON-serializable summary" do
      diff = described_class.between(
        build_entity("MDC_P001" => "X"),
        build_entity("MDC_P001" => "Y", "MDC_P002" => "new"),
      )
      summary = diff.to_h
      expect(summary[:irdi]).to eq("0112/2///TEST#AAA001")
      expect(summary[:added]).to eq(["MDC_P002"])
      expect(summary[:removed]).to eq([])
      expect(summary[:changed].first).to include(field: "MDC_P001", from: "X", to: "Y")
    end
  end

  describe "with real entities from the oceanrunner fixture" do
    let(:database) { Opencdd::Cddal.parse_file(REFERENCE_DOCS.join("examples/oceanrunner.cddal")) }
    let(:klass) { database.classes.first }

    it "produces an empty diff between an entity and itself" do
      diff = described_class.between(klass, klass)
      expect(diff).to be_empty
    end

    it "detects a synthetic change" do
      twin = Opencdd::Klass.new(
        irdi: klass.irdi,
        properties: klass.properties.merge("MDC_P004.en" => "Mutated Name"),
      )
      diff = described_class.between(klass, twin)
      expect(diff.changed.size).to be > 0
    end
  end
end
