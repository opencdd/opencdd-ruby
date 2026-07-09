# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Cdd::Database end-to-end" do
  describe "loading the ParcelMaker xlsx" do
    subject(:db) { Cdd::Database.load(PARCEL_MAKER_XLSX.to_s) }

    it "exposes non-empty collections of every entity type" do
      expect(db.classes.size).to be >= 360
      expect(db.properties.size).to be > 500
      expect(db.units.size).to be > 1000
      expect(db.value_lists.size).to be > 50
      expect(db.value_terms.size).to be > 300
    end

    it "builds the class hierarchy from the Superclass column" do
      roots = db.root_classes
      expect(roots.size).to be >= 1
      expect(roots.map(&:code)).to include("ACC001")
      acc001 = db.find_by_code("ACC001")
      expect(acc001.children.map(&:code)).to include("ACC010", "ACC100")
    end

    it "finds entities by full IRDI" do
      irdi = Cdd::IRDI.parse("0112/2///62683#ACC001")
      entity = db.find(irdi)
      expect(entity).to be_a(Cdd::Klass)
      expect(entity.preferred_name).to eq("LV switchgear and controlgear domain")
    end

    it "finds entities by short code" do
      entity = db.find_by_code("ACC010")
      expect(entity).to be_a(Cdd::Klass)
      expect(entity.preferred_name).to match(/blocks of properties/)
    end

    it "walks ancestors from a deep class" do
      leaf = db.find_by_code("ACC011")
      chain = leaf.ancestors.map(&:code)
      expect(chain.first).to eq("ACC011")
      expect(chain).to include("ACC010", "ACC001")
    end
  end

  describe "loading the legacy 6-file set" do
    subject(:db) { Cdd::Database.load(LEGACY_XLS_DIR.to_s) }

    it "loads at least one entity of each standard type" do
      expect(db.classes.size).to be > 100
      expect(db.properties.size).to be > 100
      expect(db.value_lists.size).to be > 10
      expect(db.value_terms.size).to be > 10
    end

    it "builds the class hierarchy from the legacy CLASS file" do
      acc001 = db.find_by_code("ACC001")
      expect(acc001).to be_a(Cdd::Klass)
      expect(acc001.children.map(&:code)).to include("ACC010")
    end
  end

  describe "loading a single legacy .xls file" do
    subject(:db) { Cdd::Database.load(LEGACY_SINGLE_XLS.to_s) }

    it "loads the file without error" do
      expect(db.entities.size).to be > 0
    end
  end

  describe "Cdd::Reader.detect" do
    it "detects ParcelMaker xlsx" do
      expect(Cdd::Reader.detect(PARCEL_MAKER_XLSX.to_s)).to eq(:xlsx)
    end

    it "detects a legacy directory" do
      expect(Cdd::Reader.detect(LEGACY_XLS_DIR.to_s)).to eq(:legacy_dir)
    end

    it "detects a single legacy xls" do
      expect(Cdd::Reader.detect(LEGACY_SINGLE_XLS.to_s)).to eq(:legacy_single)
    end
  end
end
