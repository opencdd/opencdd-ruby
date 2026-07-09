# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::EffectiveProperties do
  let(:database) { Cdd::Cddal.parse_file(REFERENCE_DOCS.join("examples/oceanrunner.cddal")) }

  describe "#for" do
    it "returns a Result that exposes properties and sources" do
      vehicle = database.find_by_code("AAA001")
      result = described_class.new(database).for(vehicle)
      expect(result).to be_a(Cdd::EffectiveProperties::Result)
      expect(result.properties).to all(be_a(Cdd::Property))
      expect(result.sources).to be_a(Hash)
    end

    it "is Enumerable" do
      vehicle = database.find_by_code("AAA001")
      result = described_class.new(database).for(vehicle)
      expect(result.size).to eq(result.properties.size)
      expect(result.map(&:code)).to include("AAAP001", "AAAP002", "AAAP003")
    end

    it "includes own applicable properties" do
      vehicle = database.find_by_code("AAA001")
      result = described_class.new(database).for(vehicle)
      expect(result.codes).to contain_exactly("AAAP001", "AAAP002", "AAAP003")
    end

    it "includes inherited applicable properties via superclass chain" do
      boat = database.find_by_code("AAA010")
      result = described_class.new(database).for(boat)
      expect(result.codes).to contain_exactly(
        "AAAP001", "AAAP002", "AAAP003",
        "AAAP010", "AAAP011", "AAAP012",
      )
    end

    it "aggregates is_case_of properties across multi-domain powertype" do
      tm = database.find_by_code("AAA100")
      result = described_class.new(database).for(tm)
      expect(result.codes).to contain_exactly(
        "AAAP001", "AAAP002", "AAAP003",
        "AAAP010", "AAAP011", "AAAP012",
        "AAAP020", "AAAP021", "AAAP022",
        "AAAP030", "AAAP031",
        "AAAP100", "AAAP101", "AAAP102", "AAAP103",
      )
      expect(result.size).to eq(15)
    end

    it "cascades through OceanRunner which subclasses TransmediumVehicle" do
      oceanrunner = database.find_by_code("BBB001")
      result = described_class.new(database).for(oceanrunner)
      expect(result.size).to eq(19)
      expect(result.codes).to include("BBAP001", "BBAP002", "BBAP003", "BBAP004")
    end

    it "deduplicates properties reachable through multiple paths" do
      tm = database.find_by_code("AAA100")
      result = described_class.new(database).for(tm)
      irdi_counts = result.properties.map(&:irdi).tally
      expect(irdi_counts.values.uniq).to eq([1])
    end

    it "tracks the source class that contributed each property" do
      boat = database.find_by_code("AAA010")
      result = described_class.new(database).for(boat)
      hull_length = database.find_by_code("AAAP010")
      contributing = result.sources[hull_length.irdi.to_s]
      expect(contributing.map(&:code)).to include("AAA010")
    end

    it "returns empty for an unknown class" do
      result = described_class.new(database).for("UNKNOWN_CODE")
      expect(result.size).to be_zero
    end
  end

  describe "cycle detection" do
    it "terminates even if is_case_of creates a cycle" do
      db = Cdd::Database.new
      meta = Cdd::IRDI.parse("MDC_C002")
      a = Cdd::Klass.new(
        irdi: Cdd::IRDI.parse("AAA001"),
        properties: {
          "MDC_P010" => "AAA002",
          "MDC_P013" => "(AAA002)",
          "MDC_P014" => "(AAAP001)",
        },
        meta_class_irdi: meta,
      )
      b = Cdd::Klass.new(
        irdi: Cdd::IRDI.parse("AAA002"),
        properties: {
          "MDC_P010" => "AAA001",
          "MDC_P013" => "(AAA001)",
          "MDC_P014" => "(AAAP002)",
        },
        meta_class_irdi: meta,
      )
      p1 = Cdd::Property.new(
        irdi: Cdd::IRDI.parse("AAAP001"),
        properties: { "MDC_P001_6" => "AAAP001" },
        meta_class_irdi: Cdd::IRDI.parse("MDC_C003"),
      )
      p2 = Cdd::Property.new(
        irdi: Cdd::IRDI.parse("AAAP002"),
        properties: { "MDC_P001_6" => "AAAP002" },
        meta_class_irdi: Cdd::IRDI.parse("MDC_C003"),
      )
      db.add_entity(a)
      db.add_entity(b)
      db.add_entity(p1)
      db.add_entity(p2)
      db.finalize!

      result = described_class.new(db).for(a)
      expect(result.codes).to contain_exactly("AAAP001", "AAAP002")
    end
  end

  describe "#codes_for" do
    it "returns the codes of the resolved properties" do
      vehicle = database.find_by_code("AAA001")
      engine = described_class.new(database)
      expect(engine.codes_for(vehicle)).to contain_exactly("AAAP001", "AAAP002", "AAAP003")
    end
  end
end
