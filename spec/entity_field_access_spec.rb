# frozen_string_literal: true

require "spec_helper"

# Spec coverage for the Entity field-access seam added in P26.
# These are the canonical public methods for reading and writing
# typed fields. Callers that index `entity.properties[pid]`
# directly bypass these and risk round-trip drift.

RSpec.describe Opencdd::Entity, "#read_field" do
  let(:klass) do
    Opencdd::Klass.new(
      irdi: Opencdd::IRDI.parse("0112/2///61360_4#AAA001"),
      properties: {
        "MDC_P001_5"  => "AAA001",
        "MDC_P004.en" => "Vehicle",
        "MDC_P004.fr" => "Véhicule",
        "MDC_P011"    => "ITEM_CLASS",
      },
      meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
    )
  end

  it "reads a declared field by name" do
    expect(klass.read_field(:version)).to eq(klass.properties["MDC_P002_1"])
  end

  it "reads a multilingual field with lang:" do
    expect(klass.read_field(:preferred_name, lang: :fr)).to eq("Véhicule")
  end

  it "falls back to source language when the requested lang is missing" do
    expect(klass.read_field(:preferred_name, lang: :de)).to eq("Vehicle")
  end

  it "returns nil for unknown fields" do
    expect(klass.read_field(:nonexistent)).to be_nil
  end

  it "reads the class_type field as a parsed ClassType" do
    ct = klass.read_field(:class_type)
    expect(ct).to be_a(Opencdd::ClassType)
    expect(ct.to_s).to eq("ITEM_CLASS")
  end

  it "reads the superclass_irdi field as a parsed IRDI" do
    k = Opencdd::Klass.new(
      irdi: Opencdd::IRDI.parse("0112/2///61360_4#AAA002"),
      properties: { "MDC_P001_5" => "AAA002", "MDC_P010" => "AAA001" },
      meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
    )
    expect(k.read_field(:superclass_irdi)).to be_a(Opencdd::IRDI)
    expect(k.read_field(:superclass_irdi).code).to eq("AAA001")
  end
end

RSpec.describe Opencdd::Entity, "#write_property!" do
  let(:klass) do
    Opencdd::Klass.new(
      irdi: Opencdd::IRDI.parse("0112/2///61360_4#AAA001"),
      properties: { "MDC_P001_5" => "AAA001" },
      meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
    )
  end

  it "writes a value under the canonical property ID" do
    klass.write_property!("MDC_P066", "abc-123")
    expect(klass.properties["MDC_P066"]).to eq("abc-123")
  end

  it "resolves aliases to canonical IDs" do
    klass.write_property!(:data_type, "REAL_TYPE")
    expect(klass.properties["MDC_P022"]).to eq("REAL_TYPE")
  end

  it "coerces the value to string" do
    klass.write_property!("MDC_P002_1", 42)
    expect(klass.properties["MDC_P002_1"]).to eq("42")
  end

  it "returns self for chaining" do
    expect(klass.write_property!("MDC_P011", "ITEM_CLASS")).to equal(klass)
  end
end

RSpec.describe "Entity#write_property! used by GUID.set_on" do
  it "writes the GUID through the field seam" do
    entity = Opencdd::Klass.new(
      irdi: Opencdd::IRDI.parse("0112/2///61360_4#AAA001"),
      properties: {},
      meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
    )
    guid = Opencdd::GUID.set_on(entity)
    expect(entity.properties[Opencdd::PropertyIds::MDC_P066]).to eq(guid)
    expect(Opencdd::GUID.valid?(guid)).to be(true)
  end
end
