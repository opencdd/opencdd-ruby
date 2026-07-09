# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::AliasTable do
  describe "initialized with defaults" do
    it "populates built-in aliases from PropertyIds" do
      table = described_class.new(defaults: true)
      expect(table.resolve("code")).to eq("MDC_P001_5")
      expect(table.resolve("superclass")).to eq("MDC_P010")
      expect(table.resolve("data_type")).to eq("MDC_P022")
      expect(table.resolve("unit")).to eq("MDC_P041")
    end

    it "reports keys via key?" do
      table = described_class.new(defaults: true)
      expect(table.key?("definition")).to be(true)
      expect(table.key?("does_not_exist")).to be(false)
    end

    it "exposes size matching PropertyIds alias count" do
      table = described_class.new(defaults: true)
      expect(table.size).to eq(Cdd::PropertyIds.alias_map.size)
    end
  end

  describe "initialized without defaults" do
    it "starts empty" do
      table = described_class.new(defaults: false)
      expect(table.size).to be_zero
      expect(table.resolve("code")).to be_nil
    end
  end

  describe "#declare" do
    it "adds a new alias" do
      table = described_class.new(defaults: false)
      table.declare("colour", "MDC_P004")
      expect(table.resolve("colour")).to eq("MDC_P004")
    end

    it "is idempotent when re-declaring the same alias to the same target" do
      table = described_class.new(defaults: false)
      table.declare("colour", "MDC_P004")
      expect { table.declare("colour", "MDC_P004") }.not_to raise_error
      expect(table.size).to eq(1)
    end

    it "raises ArgumentError when re-declaring the same alias to a different target" do
      table = described_class.new(defaults: false)
      table.declare("colour", "MDC_P004")
      expect { table.declare("colour", "MDC_P005") }.to raise_error(ArgumentError, /duplicate alias/)
    end

    it "raises ArgumentError for unknown property id" do
      table = described_class.new(defaults: false)
      expect { table.declare("colour", "MDC_P999") }.to raise_error(ArgumentError, /unknown property id/)
    end

    it "returns self for chaining" do
      table = described_class.new(defaults: false)
      expect(table.declare("colour", "MDC_P004")).to equal(table)
    end
  end

  describe "#redeclare" do
    it "forcefully overrides an existing alias" do
      table = described_class.new(defaults: false)
      table.declare("colour", "MDC_P004")
      table.redeclare("colour", "MDC_P005")
      expect(table.resolve("colour")).to eq("MDC_P005")
    end

    it "raises for unknown property id" do
      table = described_class.new(defaults: false)
      expect { table.redeclare("colour", "MDC_P999") }.to raise_error(ArgumentError, /unknown property id/)
    end
  end

  describe "#each" do
    it "yields alias_name, property_id pairs" do
      table = described_class.new(defaults: false)
      table.declare("alpha", "MDC_P004")
      table.declare("beta",  "MDC_P005")
      pairs = []
      table.each { |name, id| pairs << [name, id] }
      expect(pairs).to contain_exactly(["alpha", "MDC_P004"], ["beta", "MDC_P005"])
    end
  end

  describe "#to_h" do
    it "returns a duplicate of the underlying table" do
      table = described_class.new(defaults: false)
      table.declare("alpha", "MDC_P004")
      snapshot = table.to_h
      snapshot["alpha"] = "tampered"
      expect(table.resolve("alpha")).to eq("MDC_P004")
    end
  end
end
