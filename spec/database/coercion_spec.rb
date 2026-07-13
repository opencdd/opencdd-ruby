# frozen_string_literal: true

require "spec_helper"

# Spec coverage for the entity-or-IRDI coercion helpers added in
# plan 16 (audit A2). Single point of truth for the pattern that
# used to be inlined at 15+ call sites.

RSpec.describe Opencdd::Database, "#coerce_entity" do
  let(:db) { Opencdd::Database.new }
  let(:klass) do
    Opencdd::Klass.new(
      irdi: Opencdd::IRDI.parse("0112/2///61360_4#AAA001"),
      properties: { "MDC_P001_5" => "0112/2///61360_4#AAA001" },
      meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
    )
  end

  before { db.add_entity(klass) }

  it "returns the entity when given an Entity" do
    expect(db.coerce_entity(klass)).to equal(klass)
  end

  it "resolves an IRDI to the entity" do
    expect(db.coerce_entity(klass.irdi)).to eq(klass)
  end

  it "resolves a String IRDI to the entity" do
    expect(db.coerce_entity("0112/2///61360_4#AAA001")).to eq(klass)
  end

  it "returns nil for unknown IRDI" do
    expect(db.coerce_entity("0112/2///61360_4#UNKNOWN")).to be_nil
  end

  it "returns nil for nil input" do
    expect(db.coerce_entity(nil)).to be_nil
  end

  it "returns nil for unparseable input" do
    expect(db.coerce_entity("not an irdi")).to be_nil
  end
end

RSpec.describe Opencdd::Database, "#coerce_irdi" do
  let(:db) { Opencdd::Database.new }
  let(:klass) do
    Opencdd::Klass.new(
      irdi: Opencdd::IRDI.parse("0112/2///61360_4#AAA001"),
      properties: { "MDC_P001_5" => "0112/2///61360_4#AAA001" },
      meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
    )
  end
  let(:irdi) { Opencdd::IRDI.parse("0112/2///61360_4#AAA001") }

  it "returns the entity's irdi when given an Entity" do
    expect(db.coerce_irdi(klass)).to eq(irdi)
  end

  it "returns the IRDI when given an IRDI" do
    expect(db.coerce_irdi(irdi)).to equal(irdi)
  end

  it "parses a String into an IRDI" do
    expect(db.coerce_irdi("0112/2///61360_4#AAA001")).to eq(irdi)
  end

  it "returns nil for nil input" do
    expect(db.coerce_irdi(nil)).to be_nil
  end

  # Note: Opencdd::IRDI.parse is permissive (accepts any string as a
  # degenerate IRDI). Stricter validation belongs in IRDI.parse, not
  # in coerce_irdi — coerce_irdi's contract is "always return an IRDI
  # (or nil) for non-nil input, delegating parsing to IRDI.parse".
  it "always delegates to IRDI.parse for non-nil input" do
    expect(db.coerce_irdi("anything")).to be_a(Opencdd::IRDI)
  end
end
