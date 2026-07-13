# frozen_string: true

require "spec_helper"

# Spec coverage for the CDD-native YAML model (plan 33).
# YAML is the canonical persistence format, using semantic CDD
# attribute names (preferred_name, superclass, class_type) — not
# wire-format keys (MDC_P004, MDC_P010).

RSpec.describe "CDD-native YAML model", :yaml do
  let(:oceanrunner) { Opencdd::Cddal.parse_file(REFERENCE_DOCS.join("examples/oceanrunner.cddal")) }

  describe "Database#to_yaml → Database.from_yaml round-trip" do
    it "produces valid YAML" do
      yaml = oceanrunner.to_yaml
      expect(yaml).to include("irdi:")
      expect(yaml).to include("preferred_name:")
      expect(yaml).to include("class_type:")
    end

    it "uses semantic CDD attribute names (not MDC_P### keys)" do
      yaml = oceanrunner.to_yaml
      expect(yaml).to include("preferred_name:")
      expect(yaml).not_to include("MDC_P004:")
    end

    it "round-trips through YAML preserving entity count" do
      yaml = oceanrunner.to_yaml
      db2 = Opencdd::Database.from_yaml(yaml)
      expect(db2.entities.size).to eq(oceanrunner.entities.size)
    end

    it "round-trips preserving entity types" do
      yaml = oceanrunner.to_yaml
      db2 = Opencdd::Database.from_yaml(yaml)
      expect(db2.classes.size).to eq(oceanrunner.classes.size)
      expect(db2.properties.size).to eq(oceanrunner.properties.size)
    end

    it "round-trips preserving preferred_name (multilingual)" do
      yaml = oceanrunner.to_yaml
      db2 = Opencdd::Database.from_yaml(yaml)
      vehicle = db2.find_by_code("AAA001")
      expect(vehicle).not_to be_nil
      expect(vehicle.preferred_name).to eq("Vehicle")
    end

    it "round-trips preserving class_type" do
      yaml = oceanrunner.to_yaml
      db2 = Opencdd::Database.from_yaml(yaml)
      engine = db2.find_by_code("AAA200")
      expect(engine).not_to be_nil
      expect(engine.class_type.to_s).to eq("CATEGORICAL_CLASS")
    end

    it "round-trips preserving powertype semantics" do
      yaml = oceanrunner.to_yaml
      db2 = Opencdd::Database.from_yaml(yaml)
      engine = db2.find_by_code("AAA200")
      expect(engine).to be_powertype
      expect(db2.instances_of(engine).map(&:code).sort)
        .to eq(%w[AAA201 AAA202 AAA203])
    end

    it "round-trips preserving superclass relationships" do
      yaml = oceanrunner.to_yaml
      db2 = Opencdd::Database.from_yaml(yaml)
      boat = db2.find_by_code("AAA010")
      expect(boat).not_to be_nil
      expect(boat.parent_irdi).not_to be_nil
    end
  end

  describe Opencdd::Model::YamlEntity do
    it "serializes a single entity to YAML with semantic names" do
      vehicle = oceanrunner.find_by_code("AAA001")
      yaml_entity = Opencdd::Model::YamlEntity.from_entity(vehicle)
      yaml = yaml_entity.to_yaml
      expect(yaml).to include("preferred_name:")
      expect(yaml).to include("en: Vehicle")
    end

    it "deserializes from YAML back to an Entity" do
      vehicle = oceanrunner.find_by_code("AAA001")
      yaml_entity = Opencdd::Model::YamlEntity.from_entity(vehicle)
      yaml = yaml_entity.to_yaml
      parsed = Opencdd::Model::YamlEntity.from_yaml(yaml)
      entity = parsed.to_entity
      expect(entity.code).to eq("AAA001")
      expect(entity.preferred_name).to eq("Vehicle")
    end
  end

  describe "multilingual fields as nested Hash" do
    it "emits preferred_name as a lang→text hash" do
      # Find an entity with multiple languages (if any in the fixture)
      yaml = oceanrunner.to_yaml
      # The fixture has at least English
      expect(yaml).to match(/preferred_name:\s*\n\s*en:\s*\w+/)
    end
  end

  describe "collection fields as YAML arrays" do
    it "emits applicable_properties as an array" do
      vehicle = oceanrunner.find_by_code("AAA001")
      yaml_entity = Opencdd::Model::YamlEntity.from_entity(vehicle)
      yaml = yaml_entity.to_yaml
      expect(yaml).to include("applicable_properties:")
    end
  end
end
