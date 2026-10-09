# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::EffectiveProperties do
  before { require_fixture OCEANRUNNER }
  let(:database) { Opencdd::Cddal.parse_file(OCEANRUNNER) }

  describe "#for" do
    it "returns a Result that exposes properties and sources" do
      vehicle = database.find_by_code("ORA001")
      result = described_class.new(database).for(vehicle)
      expect(result).to be_a(Opencdd::EffectiveProperties::Result)
      expect(result.properties).to all(be_a(Opencdd::Property))
      expect(result.sources).to be_a(Hash)
    end

    it "is Enumerable" do
      vehicle = database.find_by_code("ORA001")
      result = described_class.new(database).for(vehicle)
      expect(result.size).to eq(result.properties.size)
      expect(result.map(&:code)).to include("ORB001", "ORB002", "ORB003")
    end

    it "includes own applicable properties" do
      vehicle = database.find_by_code("ORA001")
      result = described_class.new(database).for(vehicle)
      expect(result.codes).to contain_exactly("ORB001", "ORB002", "ORB003", "ORB004",
                                              "ORB005", "ORB006", "ORB007", "ORB008")
    end

    it "includes inherited applicable properties via superclass chain" do
      boat = database.find_by_code("ORA010")
      result = described_class.new(database).for(boat)
      expect(result.codes).to contain_exactly(
        "ORB001", "ORB002", "ORB003", "ORB004",
        "ORB005", "ORB006", "ORB007", "ORB008",
        "ORB010", "ORB011", "ORB012", "ORB013", "ORB014", "ORB015",
      )
    end

    it "aggregates is_case_of properties across multi-domain powertype" do
      tm = database.find_by_code("ORA100")
      result = described_class.new(database).for(tm)
      expect(result.codes).to contain_exactly(
        "ORB001", "ORB002", "ORB003", "ORB004",
        "ORB005", "ORB006", "ORB007", "ORB008",
        "ORB010", "ORB011", "ORB012", "ORB013", "ORB014", "ORB015",
        "ORB020", "ORB021", "ORB022", "ORB023", "ORB024", "ORB025", "ORB026",
        "ORB030", "ORB031", "ORB032", "ORB033", "ORB034",
        "ORB100", "ORB101", "ORB102", "ORB103", "ORB104", "ORB105",
      )
      expect(result.size).to eq(32)
    end

    it "cascades through OceanRunner which subclasses TransmediumVehicle" do
      oceanrunner = database.find_by_code("ORA300")
      result = described_class.new(database).for(oceanrunner)
      expect(result.size).to eq(38)
      expect(result.codes).to include("ORB301", "ORB302", "ORB303", "ORB304")
    end

    it "deduplicates properties reachable through multiple paths" do
      tm = database.find_by_code("ORA100")
      result = described_class.new(database).for(tm)
      irdi_counts = result.properties.map(&:irdi).tally
      expect(irdi_counts.values.uniq).to eq([1])
    end

    it "tracks the source class that contributed each property" do
      boat = database.find_by_code("ORA010")
      result = described_class.new(database).for(boat)
      hull_length = database.find_by_code("ORB010")
      contributing = result.sources[hull_length.irdi.to_s]
      expect(contributing.map(&:code)).to include("ORA010")
    end

    it "returns empty for an unknown class" do
      result = described_class.new(database).for("UNKNOWN_CODE")
      expect(result.size).to be_zero
    end
  end

  describe "cycle detection" do
    it "terminates even if is_case_of creates a cycle" do
      db = Opencdd::Database.new
      meta = Opencdd::IRDI.parse("MDC_C002")
      a = Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse("ORA001"),
        properties: {
          "MDC_P010" => "AAA002",
          "MDC_P013" => "(AAA002)",
          "MDC_P014" => "(ORB001)",
        },
        meta_class_irdi: meta,
      )
      b = Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse("AAA002"),
        properties: {
          "MDC_P010" => "ORA001",
          "MDC_P013" => "(ORA001)",
          "MDC_P014" => "(ORB002)",
        },
        meta_class_irdi: meta,
      )
      p1 = Opencdd::Property.new(
        irdi: Opencdd::IRDI.parse("ORB001"),
        properties: { "MDC_P001_6" => "ORB001" },
        meta_class_irdi: Opencdd::IRDI.parse("MDC_C003"),
      )
      p2 = Opencdd::Property.new(
        irdi: Opencdd::IRDI.parse("ORB002"),
        properties: { "MDC_P001_6" => "ORB002" },
        meta_class_irdi: Opencdd::IRDI.parse("MDC_C003"),
      )
      db.add_entity(a)
      db.add_entity(b)
      db.add_entity(p1)
      db.add_entity(p2)
      db.finalize!

      result = described_class.new(db).for(a)
      expect(result.codes).to contain_exactly("ORB001", "ORB002")
    end
  end

  describe "#codes_for" do
    it "returns the codes of the resolved properties" do
      vehicle = database.find_by_code("ORA001")
      engine = described_class.new(database)
      expect(engine.codes_for(vehicle)).to contain_exactly("ORB001", "ORB002", "ORB003", "ORB004",
                                                            "ORB005", "ORB006", "ORB007", "ORB008")
    end
  end
end
