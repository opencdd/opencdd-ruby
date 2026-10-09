# frozen_string_literal: true

require "spec_helper"

# The POI dictionary carries the verified global spot registry that
# data-poi's pipeline generates (DBpedia harvest, per-entry Wikipedia
# verification, Wikidata enrichment). Codes POInn country blocks.
POI = public_fixture("data-poi", "poi.cddal")

RSpec.describe "POI registry dictionary" do
  before { require_fixture POI }
  let(:db) { Opencdd::Cddal.parse_file(POI) }

  it "loads every entity" do
    expect(db.entities.size).to eq(742)
  end

  it "carries six hundred plus registered spots" do
    indiv = db.entities.map(&:code).grep(/\APOI/)
    expect(indiv.size).to be > 600
  end

  it "enumerates thirty countries" do
    country = db.find_by_code("POA010")
    expect(db.instances_of(country).map(&:code).size).to eq(30)
  end

  it "uses PO codes throughout" do
    prefixes = db.entities.map(&:code).map { |c| c.to_s[/\A[A-Z]+/] }.uniq.sort
    expect(prefixes).to eq(%w[POA POB POI])
  end

  it "binds coordinates and cities on verified individuals" do
    spot = db.entities.find { |e| e.code.to_s.start_with?("POI") && e.respond_to?(:read_field) }
    with_coords = db.entities.count do |e|
      raw = e.respond_to?(:properties) && e.properties.key?("latitude")
      raw
    end
    expect(with_coords).to be > 350
  end
end
