# frozen_string_literal: true

require "spec_helper"

# Spec coverage for Database#each_reference_collection (P22).
# This is the single iteration shape for walking every set_of_refs
# property across every entity. Both normalize_reference_collections!
# and rewrite_back_references! use it.

RSpec.describe Opencdd::Database, "#each_reference_collection" do
  let(:db) do
    Opencdd::Database.new.tap do |d|
      klass = Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse("0112/2///61360_4#AAA001"),
        properties: {
          "MDC_P001_5" => "AAA001",
          "MDC_P014"   => "{AAAP001,AAAP002}",
          "MDC_P013"   => "{AAA010,AAA020}",
        },
        meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
      )
      d.add_entity(klass)
    end
  end

  it "yields (entity, property_id, raw, elements) for each set_of_refs property" do
    results = []
    db.each_reference_collection do |entity, pid, raw, elements|
      results << [pid, elements]
    end
    pids = results.map(&:first).sort
    expect(pids).to include("MDC_P014", "MDC_P013")
  end

  it "splits elements via StructuredValues.unwrap_and_split" do
    db.each_reference_collection do |entity, pid, raw, elements|
      if pid == "MDC_P014"
        expect(elements).to eq(%w[AAAP001 AAAP002])
      end
    end
  end

  it "returns an Enumerator when no block is given" do
    enum = db.each_reference_collection
    expect(enum).to be_an(Enumerator)
    expect(enum.to_a.size).to eq(2)
  end

  it "skips nil/empty properties" do
    db2 = Opencdd::Database.new
    klass = Opencdd::Klass.new(
      irdi: Opencdd::IRDI.parse("0112/2///61360_4#AAA099"),
      properties: { "MDC_P001_5" => "AAA099", "MDC_P014" => nil },
      meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
    )
    db2.add_entity(klass)
    expect(db2.each_reference_collection.to_a).to be_empty
  end
end
