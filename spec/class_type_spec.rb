# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::ClassType do
  describe "VALUES" do
    it "exposes the canonical set of class_type codes" do
      expect(described_class::VALUES).to eq(%w[ITEM_CLASS CATEGORICAL_CLASS VALUE_CLASS MESSAGE_CLASS])
      expect(described_class::VALUES).to be_frozen
    end
  end

  describe "#initialize" do
    it "accepts each canonical value" do
      expect(described_class.new("ITEM_CLASS").to_s).to eq("ITEM_CLASS")
      expect(described_class.new("CATEGORICAL_CLASS").to_s).to eq("CATEGORICAL_CLASS")
    end

    it "raises ArgumentError for unknown value" do
      expect { described_class.new("UNKNOWN") }.to raise_error(ArgumentError, /unknown class_type/)
    end
  end

  describe ".parse" do
    it "parses canonical values" do
      parsed = described_class.parse("item_class")
      expect(parsed).to be_a(described_class)
      expect(parsed.item?).to be(true)
    end

    it "returns nil for nil/empty input" do
      expect(described_class.parse(nil)).to be_nil
      expect(described_class.parse("")).to be_nil
      expect(described_class.parse("   ")).to be_nil
    end

    it "returns nil for unknown values" do
      expect(described_class.parse("UNKNOWN")).to be_nil
    end
  end

  describe "predicates" do
    it "item_class is item? and not categorical?" do
      ct = described_class.new("ITEM_CLASS")
      expect(ct.item?).to be(true)
      expect(ct.categorical?).to be(false)
    end

    it "categorical_class is categorical? and not item?" do
      ct = described_class.new("CATEGORICAL_CLASS")
      expect(ct.categorical?).to be(true)
      expect(ct.item?).to be(false)
    end

    it "value_class is value_class?" do
      expect(described_class.new("VALUE_CLASS").value_class?).to be(true)
    end

    it "message_class is message?" do
      expect(described_class.new("MESSAGE_CLASS").message?).to be(true)
    end
  end

  describe "dynamic predicate methods" do
    it "defines a predicate for each value" do
      described_class::VALUES.each do |v|
        predicate = "#{v.downcase}?"
        expect(described_class.new(v).public_send(predicate)).to be(true)
      end
    end
  end

  describe "#to_sym" do
    it "downcases the value" do
      expect(described_class.new("ITEM_CLASS").to_sym).to eq(:item_class)
    end
  end
end
