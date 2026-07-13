# frozen_string: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Per-entity YAML persistence", :yaml do
  let(:oceanrunner) { Opencdd::Cddal.parse_file(REFERENCE_DOCS.join("examples/oceanrunner.cddal")) }

  describe "Database#save_to_directory / load_from_directory" do
    it "writes one YAML file per entity (via lutaml-store DatabaseStore)" do
      Dir.mktmpdir("entity-store") do |dir|
        oceanrunner.save_to_directory(dir)
        yaml_files = Dir.glob("#{dir}/**/*.yaml")
        expect(yaml_files.size).to eq(oceanrunner.entities.size)
      end
    end

    it "each file uses CDD-native attribute names" do
      Dir.mktmpdir("entity-store") do |dir|
        oceanrunner.save_to_directory(dir)
        first_file = Dir.glob("#{dir}/**/*.yaml").first
        content = File.read(first_file)
        expect(content).to include("preferred_name:")
        expect(content).not_to include("MDC_P004:")
      end
    end

    it "round-trips preserving entity count" do
      Dir.mktmpdir("entity-store") do |dir|
        oceanrunner.save_to_directory(dir)
        db2 = Opencdd::Database.load_from_directory(dir)
        expect(db2.entities.size).to eq(oceanrunner.entities.size)
      end
    end

    it "round-trips preserving entity types" do
      Dir.mktmpdir("entity-store") do |dir|
        oceanrunner.save_to_directory(dir)
        db2 = Opencdd::Database.load_from_directory(dir)
        expect(db2.classes.size).to eq(oceanrunner.classes.size)
        expect(db2.properties.size).to eq(oceanrunner.properties.size)
      end
    end

    it "round-trips preserving preferred_name" do
      Dir.mktmpdir("entity-store") do |dir|
        oceanrunner.save_to_directory(dir)
        db2 = Opencdd::Database.load_from_directory(dir)
        vehicle = db2.find_by_code("AAA001")
        expect(vehicle).not_to be_nil
        expect(vehicle.preferred_name).to eq("Vehicle")
      end
    end

    it "round-trips preserving powertype semantics" do
      Dir.mktmpdir("entity-store") do |dir|
        oceanrunner.save_to_directory(dir)
        db2 = Opencdd::Database.load_from_directory(dir)
        engine = db2.find_by_code("AAA200")
        expect(engine).to be_powertype
        expect(db2.instances_of(engine).map(&:code).sort)
          .to eq(%w[AAA201 AAA202 AAA203])
      end
    end

    it "persists data to disk (lutaml-store manages the layout)" do
      Dir.mktmpdir("entity-store") do |dir|
        oceanrunner.save_to_directory(dir)
        yaml_files = Dir.glob("#{dir}/**/*.yaml")
        expect(yaml_files.size).to eq(40)
      end
    end
  end

  describe Opencdd::Model::EntityStore do
    it "initializes with a path" do
      store = described_class.new("/tmp/test-store")
      expect(store.path).to eq("/tmp/test-store")
    end

    it "save_database writes files to disk" do
      Dir.mktmpdir("entity-store") do |dir|
        store = described_class.new(dir)
        store.save_database(oceanrunner)
        expect(Dir.glob("#{dir}/**/*.yaml").size).to eq(40)
      end
    end

    it "load_database reads files back" do
      Dir.mktmpdir("entity-store") do |dir|
        store = described_class.new(dir)
        store.save_database(oceanrunner)
        db = store.load_database
        expect(db.entities.size).to eq(40)
      end
    end
  end
end
