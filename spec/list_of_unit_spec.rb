# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::ListUnit do
  it "is a subclass of Opencdd::Entity" do
    expect(described_class).to be < Opencdd::Entity
  end

  it "is autoloaded from opencdd/list_unit" do
    expect(Opencdd::ListUnit.name).to eq("Opencdd::ListUnit")
  end

  describe "meta-class registration" do
    it "is the entity_class for MDC_C0100" do
      meta = Opencdd::MetaClasses.for("MDC_C0100")
      expect(meta.entity_class).to eq(Opencdd::ListUnit)
    end

    it "resolves :list_of_unit type to MDC_C0100" do
      expect(Opencdd::MetaClasses.meta_class_for_type(:list_of_unit)).to eq("MDC_C0100")
    end

    it "has C0101 as its code property id" do
      expect(Opencdd::MetaClasses.code_property_id_for("MDC_C0100")).to eq("C0101")
    end

    it "resolves entity_class_for_type(:list_of_unit)" do
      expect(Opencdd::MetaClasses.entity_class_for_type(:list_of_unit)).to eq(Opencdd::ListUnit)
    end
  end
end

RSpec.describe Opencdd::Database do
  describe "#list_of_units" do
    it "returns entities whose type is :list_of_unit" do
      db = Opencdd::Database.new
      lou = Opencdd::ListUnit.new(
        irdi: Opencdd::IRDI.parse("0112/2///62720#UAC901"),
        properties: { "MDC_P004.en" => "SI units" },
        meta_class_irdi: Opencdd::IRDI.parse("MDC_C0100"),
      )
      db.add_entity(lou)
      expect(db.list_of_units).to include(lou)
      expect(db.list_of_units.size).to eq(1)
    end

    it "returns empty array when no list_of_units exist" do
      expect(Opencdd::Database.new.list_of_units).to eq([])
    end
  end
end

RSpec.describe Opencdd::Visitor do
  describe "#visit_list_of_units" do
    it "visits every list_of_unit in the database" do
      db = Opencdd::Database.new
      lou1 = Opencdd::ListUnit.new(
        irdi: Opencdd::IRDI.parse("0112/2///62720#UAC901"),
        properties: {},
        meta_class_irdi: Opencdd::IRDI.parse("MDC_C0100"),
      )
      lou2 = Opencdd::ListUnit.new(
        irdi: Opencdd::IRDI.parse("0112/2///62720#UAC902"),
        properties: {},
        meta_class_irdi: Opencdd::IRDI.parse("MDC_C0100"),
      )
      db.add_entity(lou1)
      db.add_entity(lou2)

      visitor = Opencdd::Visitor.new
      visitor.visit_list_of_units(db)
      expect(visitor.seen).to include(lou1.irdi, lou2.irdi)
    end
  end

  describe "#visit_database" do
    it "includes list_of_units in the traversal" do
      db = Opencdd::Database.new
      lou = Opencdd::ListUnit.new(
        irdi: Opencdd::IRDI.parse("0112/2///62720#UAC901"),
        properties: {},
        meta_class_irdi: Opencdd::IRDI.parse("MDC_C0100"),
      )
      db.add_entity(lou)

      visitor = Opencdd::Visitor.new
      visitor.visit_database(db)
      expect(visitor.seen).to include(lou.irdi)
    end
  end
end

RSpec.describe Opencdd::Exporters::Json do
  describe "list_of_unit export" do
    let(:db) do
      db = Opencdd::Database.new
      lou = Opencdd::ListUnit.new(
        irdi: Opencdd::IRDI.parse("0112/2///62720#UAC901"),
        properties: {
          "MDC_P004.en" => "Metre-kilogram-second-ampere system of units",
          "MDC_P006.en" => "A system of units based on the metre, kilogram, second, and ampere.",
        },
        meta_class_irdi: Opencdd::IRDI.parse("MDC_C0100"),
      )
      db.add_entity(lou)
      db
    end

    it "includes list_of_unit entries in to_json output" do
      json = described_class.new.to_json(db)
      parsed = JSON.parse(json)
      lou_entry = parsed.find { |e| e["type"] == "list_of_unit" }
      expect(lou_entry).not_to be_nil
      expect(lou_entry["irdi"]).to eq("0112/2///62720#UAC901")
    end

    it "emits preferred_name for list_of_unit" do
      json = described_class.new.to_json(db)
      parsed = JSON.parse(json)
      lou_entry = parsed.find { |e| e["type"] == "list_of_unit" }
      expect(lou_entry["preferred_name"]).to eq("Metre-kilogram-second-ampere system of units")
    end

    it "payload_for dispatches to list_of_unit_node" do
      exporter = described_class.new
      payload = exporter.payload_for(db.list_of_units.first, database: db)
      expect(payload[:type]).to eq("list_of_unit")
    end
  end
end
