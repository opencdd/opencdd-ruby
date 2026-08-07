# frozen_string_literal: true

require "spec_helper"
require "json"

# Exercises the same sharded per-class fixture as
# +sharded_dir_reader_spec.rb+ (downloads/iec-63213/). KEA011 is the
# canonical worked example: it declares 7 applicable_property_irdis
# (KEA336, KEA337, KEA338, KEA321, KEA322, KEA323, KEA324) all in the
# 63213 scheme, plus one imported property (0112/2///62683#ACE808) from
# a different scheme — that cross-dict reference is what proves the
# source-scheme partitioning works.
RSpec.describe Opencdd::Parcel::ReferencedIrdis do
  FIXTURE = File.expand_path("../../downloads/iec-63213", __dir__)

  subject(:collector) { described_class.new(FIXTURE) }

  before(:all) do
    skip "sharded fixture downloads/iec-63213 not present" unless File.directory?(FIXTURE)
  end

  let(:manifest) { collector.collect }
  let(:json_payload) { collector.as_json }

  describe "#collect" do
    it "returns a Hash keyed by source scheme" do
      expect(manifest).to be_a(Hash)
      expect(manifest.keys).to all(be_a(String))
      expect(manifest).to include("63213")
    end

    it "partitions cross-dictionary IRDIs into their own scheme bucket" do
      expect(manifest).to include("62683")
      cross = manifest["62683"]
      expect(cross.map(&:irdi).map(&:to_s)).to include("0112/2///62683#ACE808")
    end

    it "tags applicable_property_irdis as :property" do
      own = manifest["63213"]
      prop_entries = own.select { |e| e.entity_type == :property }
      codes = prop_entries.map { |e| e.irdi.code }
      expect(codes).to include("KEA336", "KEA337", "KEA338",
                               "KEA321", "KEA322", "KEA323", "KEA324")
    end

    it "records the referencing class IRDI on each entry" do
      own = manifest["63213"]
      kea336 = own.find { |e| e.irdi.code == "KEA336" }
      expect(kea336.referenced_by).to include("0112/2///63213#KEA011")
    end

    it "does not double-count an IRDI referenced by multiple classes" do
      own = manifest["63213"]
      kea336_entries = own.select { |e| e.irdi.code == "KEA336" }
      expect(kea336_entries.size).to eq(1)
      entry = kea336_entries.first
      expect(entry.referenced_by).to eq(entry.referenced_by.uniq)
    end

    it "returns entries sorted by IRDI within each scheme bucket" do
      own = manifest["63213"]
      codes = own.map { |e| e.irdi.to_s }
      expect(codes).to eq(codes.sort)
    end
  end

  describe "#as_json" do
    it "produces JSON-shaped hashes with the documented keys" do
      expect(json_payload).to be_a(Hash)
      expect(json_payload["63213"]).to be_a(Array)
      first = json_payload["63213"].first
      expect(first.keys).to contain_exactly(:irdi, :entity_type,
                                            :source_scheme, :referenced_by)
    end
  end

  describe "#to_json" do
    it "round-trips through JSON.parse" do
      parsed = JSON.parse(collector.to_json)
      expect(parsed).to be_a(Hash)
      expect(parsed["63213"]).to be_an(Array)
      expect(parsed["62683"]).to be_an(Array)
    end
  end
end
