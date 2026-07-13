# frozen_string_literal: true

require "spec_helper"

# Spec coverage for the powertype API (plan A18). Powertype is
# CDD's distinguishing feature vs UML/RDF/OWL: a CATEGORICAL_CLASS
# at M1 has subclasses that ARE themselves classes but also act as
# its instances in CLASS_REFERENCE data types and sub_class_selection.
# See Opencdd module docstring + IEC 61360 §5.
#
# Fixtures used:
#   reference-docs/examples/oceanrunner.cddal
#     EngineType (CATEGORICAL_CLASS) — powertype
#       ├── SingleDieselEngine (ITEM_CLASS) — categorical instance
#       ├── TwinDieselEngine   (ITEM_CLASS) — categorical instance
#       └── ElectricHybridEngine (ITEM_CLASS) — categorical instance

RSpec.describe "Powertype API (4-layer ontology)", :cddal do
  let(:db) { Opencdd::Cddal.parse_file(REFERENCE_DOCS.join("examples/oceanrunner.cddal")) }

  let(:engine_type)      { db.find_by_code("AAA200") }
  let(:interior_package) { db.find_by_code("AAA210") }
  let(:hull_finish)      { db.find_by_code("AAA220") }
  let(:single_diesel)    { db.find_by_code("AAA201") }
  let(:twin_diesel)      { db.find_by_code("AAA202") }
  let(:electric_hybrid)  { db.find_by_code("AAA203") }
  let(:vehicle)          { db.find_by_code("AAA001") }

  describe "Klass#powertype?" do
    it "returns true for CATEGORICAL_CLASS" do
      expect(engine_type).to be_powertype
      expect(interior_package).to be_powertype
      expect(hull_finish).to be_powertype
    end

    it "returns false for ITEM_CLASS" do
      expect(vehicle).not_to be_powertype
      expect(single_diesel).not_to be_powertype
    end
  end

  describe "Klass#categorical_instances" do
    it "returns the powertype instances of a categorical class" do
      codes = engine_type.categorical_instances(db).map(&:code)
      expect(codes).to contain_exactly("AAA201", "AAA202", "AAA203")
    end

    it "is empty for a non-powertype class" do
      expect(vehicle.categorical_instances(db)).to be_empty
    end

    it "is empty when database is unavailable" do
      expect(engine_type.categorical_instances(nil)).to be_empty
    end

    it "returns InteriorPackage's options" do
      codes = interior_package.categorical_instances(db).map(&:code)
      expect(codes).to contain_exactly("AAA211", "AAA212")
    end

    it "returns HullFinish's options" do
      codes = hull_finish.categorical_instances(db).map(&:code)
      expect(codes).to contain_exactly("AAA221", "AAA222")
    end
  end

  describe "Klass#powertype_owners" do
    it "returns the categorical classes this class is an instance of" do
      owners = single_diesel.powertype_owners(db)
      expect(owners).to include(engine_type)
    end

    it "includes the categorical owner even when ancestor chain is long" do
      # OceanRunner inherits from TransmediumVehicle. ORCA30 inherits
      # from OceanRunner. ORCA30's powertype_owners should include
      # any categorical classes in the chain.
      orca30 = db.find_by_code("BBB010")
      expect(orca30.powertype_owners(db)).to be_an(Array)
    end
  end

  describe "Database#categorical_classes" do
    it "returns all categorical classes in the database" do
      codes = db.categorical_classes.map(&:code)
      expect(codes).to contain_exactly("AAA200", "AAA210", "AAA220")
    end
  end

  describe "Database#instances_of" do
    it "accepts a Klass" do
      codes = db.instances_of(engine_type).map(&:code)
      expect(codes).to contain_exactly("AAA201", "AAA202", "AAA203")
    end

    it "accepts an IRDI" do
      codes = db.instances_of(engine_type.irdi).map(&:code)
      expect(codes).to contain_exactly("AAA201", "AAA202", "AAA203")
    end

    it "accepts a code String" do
      codes = db.instances_of("AAA200").map(&:code)
      expect(codes).to contain_exactly("AAA201", "AAA202", "AAA203")
    end

    it "returns [] for a non-powertype class" do
      expect(db.instances_of(vehicle)).to be_empty
    end
  end

  describe "Database#valid_class_reference?" do
    it "accepts a valid powertype instance" do
      expect(db.valid_class_reference?(engine_type, single_diesel)).to be(true)
      expect(db.valid_class_reference?(engine_type, twin_diesel)).to be(true)
    end

    it "rejects a non-instance" do
      # InteriorPackage is not an instance of EngineType
      expect(db.valid_class_reference?(engine_type, interior_package)).to be(false)
    end

    it "rejects unknown IRDIs" do
      expect(db.valid_class_reference?(engine_type, "nonexistent")).to be(false)
    end
  end

  describe "Round-trip preservation" do
    it "preserves powertype semantics through serialize → parse" do
      out = Opencdd::Cddal.serialize(db)
      db2 = Opencdd::Cddal.parse(out)
      engine2 = db2.find_by_code("AAA200")
      expect(engine2).to be_powertype
      expect(engine2.categorical_instances(db2).map(&:code).sort)
        .to eq(%w[AAA201 AAA202 AAA203])
    end
  end
end
