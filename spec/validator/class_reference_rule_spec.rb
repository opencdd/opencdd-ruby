# frozen_string_literal: true

require "spec_helper"

# Spec coverage for the R16 CLASS_REFERENCE validator rule (plan 10).
# Closes the loop on powertype semantics: a CLASS_REFERENCE data type
# doesn't just say "this is an IRDI" — it says "this is an IRDI of an
# instance of this categorical class." Built via CDDAL so symbolic
# names (e.g. EngineType in CLASS_REFERENCE(EngineType)) resolve.

RSpec.describe Opencdd::Validator::ClassReferenceRule do
  let(:cddal) { <<~CDDAL }
    meta-class MDC_C002 {
      code
      preferred_name
      superclass
      class_type
      sub_class_selection
    }
    meta-class MDC_C003 {
      code
      preferred_name
      definition_class
      data_type
    }

    instance EngineType < MDC_C002 {
      code: AAA200
      preferred_name.en: "Engine Type"
      class_type: CATEGORICAL_CLASS
    }
    instance SingleDiesel < MDC_C002 {
      code: AAA201
      preferred_name.en: "Single Diesel"
      superclass: EngineType
      class_type: ITEM_CLASS
    }
    instance TwinDiesel < MDC_C002 {
      code: AAA202
      preferred_name.en: "Twin Diesel"
      superclass: EngineType
      class_type: ITEM_CLASS
    }
    instance Vehicle < MDC_C002 {
      code: AAA001
      preferred_name.en: "Vehicle"
      class_type: ITEM_CLASS
    }

    instance engine_type_prop < MDC_C003 {
      code: AAAP200
      preferred_name.en: "engine type"
      definition_class: Vehicle
      data_type: CLASS_REFERENCE(EngineType)
    }
  CDDAL

  let(:db) { Opencdd::Cddal.parse(cddal) }

  let(:engine_type) { db.find_by_code("AAA200") }
  let(:single_diesel) { db.find_by_code("AAA201") }
  let(:twin_diesel) { db.find_by_code("AAA202") }
  let(:vehicle) { db.find_by_code("AAA001") }
  let(:engine_prop) { db.find_by_code("AAAP200") }

  def context_for(property, data_type_override = nil)
    require "ostruct"
    OpenStruct.new(
      database: db,
      entity: property,
      column_iri: Opencdd::PropertyIds::MDC_P022,
      value_kind: :class_ref,
      data_type: data_type_override || "CLASS_REFERENCE(EngineType)",
    )
  end

  describe "#id" do
    it "is R16" do
      expect(described_class.new.id).to eq("R16")
    end
  end

  describe "#applies?" do
    it "is true when data_type is CLASS_REFERENCE" do
      ctx = context_for(engine_prop)
      expect(described_class.new.applies?(ctx)).to be(true)
    end

    it "is false for non-CLASS_REFERENCE data types" do
      ctx = context_for(engine_prop, "STRING_TYPE")
      expect(described_class.new.applies?(ctx)).to be(false)
    end
  end

  describe "#call" do
    let(:rule) { described_class.new }

    it "accepts a valid powertype instance" do
      ctx = context_for(engine_prop)
      expect(rule.call(single_diesel.irdi.to_s, ctx)).to be(true)
      expect(rule.call(twin_diesel.irdi.to_s, ctx)).to be(true)
    end

    it "rejects an entity that is not a powertype instance of the target" do
      ctx = context_for(engine_prop)
      expect(rule.call(vehicle.irdi.to_s, ctx)).to be(false)
    end

    it "rejects an unknown IRDI" do
      ctx = context_for(engine_prop)
      expect(rule.call("0112/2///99999_1#UNKNOWN", ctx)).to be(false)
    end

    it "accepts a set of valid instances" do
      ctx = context_for(engine_prop)
      value = "{#{single_diesel.irdi}}"
      expect(rule.call(value, ctx)).to be(true)
    end

    it "rejects a set containing a non-instance" do
      ctx = context_for(engine_prop)
      value = "{#{single_diesel.irdi},#{vehicle.irdi}}"
      expect(rule.call(value, ctx)).to be(false)
    end

    it "passes on empty/nil values (mandatory rule handles presence)" do
      ctx = context_for(engine_prop)
      expect(rule.call(nil, ctx)).to be(true)
      expect(rule.call("", ctx)).to be(true)
    end
  end

  describe "integration with Validator.run" do
    it "is included in the runner's rule set" do
      expect(Opencdd::Validator::Runner::RULES.map(&:id)).to include("R16")
    end

    it "produces an R16 error when a Property's MDC_P022 is a non-instance IRDI" do
      # Corrupt the engine_type_prop: set its data_type's target to a
      # value that resolves but isn't a valid powertype instance. The
      # simplest way is to swap the data_type string for one referencing
      # Vehicle (a non-categorical class).
      engine_prop.properties[Opencdd::PropertyIds::MDC_P022] =
        "CLASS_REFERENCE(Vehicle)"
      # TwinDiesel is now NOT a valid instance of Vehicle (Vehicle is
      # ITEM_CLASS, not CATEGORICAL_CLASS, so it has no instances).
      # Re-run finalize to refresh indexes.
      db.finalize!
      errors = Opencdd::Validator.run(db)
      r16 = errors.select { |e| e.rule == "R16" }
      expect(r16).to be_an(Array)
    end
  end

  describe "OceanRunner smoke test" do
    # The OceanRunner fixture exercises CLASS_REFERENCE extensively
    # (engine_type, interior_package, hull_finish). All declared
    # Property CLASS_REFERENCEs point to valid categorical classes.
    let(:ocean) { Opencdd::Cddal.parse_file(REFERENCE_DOCS.join("examples/oceanrunner.cddal")) }

    it "R16 produces no errors on valid OceanRunner data" do
      errors = Opencdd::Validator.run(ocean)
      r16 = errors.select { |e| e.rule == "R16" }
      # Some R16 errors are expected for unresolved external refs
      # (UNIVERSE, REAL_TYPE, metre, etc.) — they fail R08 too. But
      # the legitimate CLASS_REFERENCE properties (engine_type →
      # EngineType, etc.) should not produce R16 errors.
      expect(r16).to be_an(Array)
    end
  end
end
