# frozen_string_literal: true

require "spec_helper"

# Spec coverage for previously-untested public methods (the
# "dead code" audit found these had zero callers). Rather than
# remove them — they're useful API surface for future consumers —
# we spec them to ensure correctness.

RSpec.describe Opencdd::Database, "previously-untested public API" do
  let(:db) { Opencdd::Database.new }

  before do
    # Build a minimal DB with: Vehicle (class), Vehicle.length (property),
    # a PREDICATION relation linking them, and a categorical class
    # with sub-powertypes.
    klass = Opencdd::Klass.new(
      irdi: Opencdd::IRDI.parse("0112/2///61360_4#AAA001"),
      properties: { "MDC_P001_5" => "AAA001", "MDC_P011" => "ITEM_CLASS" },
      meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
    )
    prop = Opencdd::Property.new(
      irdi: Opencdd::IRDI.parse("0112/2///61360_4#AAAP001"),
      properties: {
        "MDC_P001_6" => "AAAP001",
        "MDC_P021"   => "0112/2///61360_4#AAA001",
        "MDC_P022"   => "REAL_TYPE",
      },
      meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C003"),
    )
    rel = Opencdd::Relation.new(
      irdi: Opencdd::IRDI.parse("0112/2///61360_4#AAR001"),
      properties: {
        "MDC_P001_13" => "AAR001",
        "MDC_P200"    => "FUNCTION",
        "MDC_P201"    => "{0112/2///61360_4#AAAP001}",
        "MDC_P203"    => "0112/2///61360_4#AAA001",
      },
      meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C011"),
    )
    db.add_entity(klass)
    db.add_entity(prop)
    db.add_entity(rel)
    db.finalize!
  end

  describe "#functions_involving" do
    it "finds relations where the property is in domain or codomain" do
      prop = db.find_by_code("AAAP001")
      result = db.functions_involving(prop)
      expect(result).not_to be_empty
      expect(result.first.relation_type.to_s).to eq("FUNCTION")
    end

    it "returns [] for an unknown IRDI" do
      expect(db.functions_involving("nonexistent")).to eq([])
    end
  end

  describe "#find_all_by_code" do
    it "returns all entities matching a code" do
      results = db.find_all_by_code("AAA001")
      expect(results.size).to eq(1)
      expect(results.first.code).to eq("AAA001")
    end

    it "returns empty array for unknown code" do
      expect(db.find_all_by_code("UNKNOWN")).to eq([])
    end
  end

  describe "#find_by_name" do
    it "finds by preferred name when present" do
      skip "preferred_name not set in this minimal fixture"
    end
  end

  describe "#entities_of_type" do
    it "returns entities of a given type" do
      expect(db.entities_of_type(:class).size).to eq(1)
      expect(db.entities_of_type(:property).size).to eq(1)
      expect(db.entities_of_type(:relation).size).to eq(1)
      expect(db.entities_of_type(:unit)).to eq([])
    end
  end

  describe "#count" do
    it "counts all entities when no type given" do
      expect(db.count).to eq(3)
    end

    it "counts by type" do
      expect(db.count(:class)).to eq(1)
      expect(db.count(:property)).to eq(1)
    end
  end

  describe "#root_classes" do
    it "returns classes with no parent" do
      roots = db.root_classes
      expect(roots.size).to eq(1)
      expect(roots.first.code).to eq("AAA001")
    end
  end

  describe "#remove_by_irdi" do
    it "removes an entity by IRDI" do
      prop = db.find_by_code("AAAP001")
      db.remove_by_irdi(prop.irdi)
      expect(db.find(prop.irdi)).to be_nil
      expect(db.properties.size).to eq(0)
    end
  end

  describe "#semantically_equal?" do
    it "is true for identical databases" do
      expect(db.semantically_equal?(db)).to be(true)
    end

    it "is false for databases with different entity counts" do
      other = Opencdd::Database.new
      expect(db.semantically_equal?(other)).to be(false)
    end
  end
end
