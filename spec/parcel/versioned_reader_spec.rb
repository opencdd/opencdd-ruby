# frozen_string_literal: true

require "spec_helper"

# Exercises the per-version sharded layout in downloads/iec-63213.
# KEA012 has 3 versions (current v003 + two superseded), each in its
# own UNID subfolder. The fixture is the only multi-version dict
# available without large downloads.
RSpec.describe Opencdd::Parcel::VersionedReader do
  SHARDED_FIXTURE = File.expand_path("../../downloads/iec-63213", __dir__)

  let(:reader) { described_class.new(SHARDED_FIXTURE) }

  before(:all) do
    skip "sharded fixture downloads/iec-63213 not present" unless File.directory?(SHARDED_FIXTURE)
  end

  describe "#versions_for" do
    it "returns a VersionHistory with all versions for a multi-version entity" do
      vh = reader.versions_for("KEA012")
      expect(vh).to be_a(Opencdd::Entity::VersionHistory)
      expect(vh.size).to eq(3)
    end

    it "returns an empty VersionHistory for an unknown code" do
      vh = reader.versions_for("NOPE01")
      expect(vh).to be_empty
    end

    it "includes the current version marked as current" do
      vh = reader.versions_for("KEA012")
      expect(vh.current).to be
      expect(vh.current.current?).to be(true)
    end
  end

  describe "#load_version" do
    let(:versions) { reader.versions_for("KEA012") }
    let(:current_entry) { versions.current }

    it "returns a Database with at least one entity for the current version" do
      skip "no current version in fixture" unless current_entry&.unid
      database = reader.load_version("KEA012", current_entry.unid)
      expect(database).to be_a(Opencdd::Database)
      expect(database.entities.size).to be > 0
    end

    # Historical versions in the opencdd-ruby fixture don't ship
    # with .xls files (the scraper captured only the current version's
    # exports). When the scraper is extended to capture historical
    # xls, this test will need updating. For now we assert the reader
    # returns nil gracefully when files are absent.
    it "returns nil for a historical UNID whose .xls files weren't scraped" do
      historical = versions.entries.find { |v| !v.current? }
      skip "no historical version in fixture" unless historical&.unid
      expect(reader.load_version("KEA012", historical.unid)).to be_nil
    end

    it "returns nil for an unknown UNID" do
      expect(reader.load_version("KEA012", "DEADBEEF")).to be_nil
    end

    it "returns nil for an unknown code" do
      expect(reader.load_version("NOPE01", "anything")).to be_nil
    end
  end

  describe "#entity_dir_for" do
    it "locates the entity directory under the sharded _entities layout" do
      dir = reader.entity_dir_for("KEA012")
      expect(dir).to be
      expect(File.directory?(dir)).to be(true)
    end

    it "returns nil for an unknown code" do
      expect(reader.entity_dir_for("NOPE01")).to be_nil
    end
  end
end
