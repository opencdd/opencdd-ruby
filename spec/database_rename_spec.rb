# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::Database, "#rename_entity" do
  let(:db) do
    Cdd::Database.new.tap do |d|
      parent = Cdd::Klass.new(
        irdi: Cdd::IRDI.parse("AAA001"),
        properties: {
          "MDC_P001_5" => "AAA001",
          "MDC_P011"   => "ITEM_CLASS",
          "MDC_P014"   => "(AAAP001)",
        },
        meta_class_irdi: Cdd::IRDI.parse("MDC_C002"),
      )
      child = Cdd::Klass.new(
        irdi: Cdd::IRDI.parse("AAA002"),
        properties: {
          "MDC_P001_5" => "AAA002",
          "MDC_P010"   => "AAA001",
          "MDC_P011"   => "ITEM_CLASS",
          "MDC_P013"   => "(AAA001)",
          "MDC_P014"   => "(AAAP002,AAAP003)",
        },
        meta_class_irdi: Cdd::IRDI.parse("MDC_C002"),
      )
      p1 = Cdd::Property.new(
        irdi: Cdd::IRDI.parse("AAAP001"),
        properties: {
          "MDC_P001_6" => "AAAP001",
          "MDC_P021"   => "AAA001",
          "MDC_P022"   => "STRING_TYPE",
        },
        meta_class_irdi: Cdd::IRDI.parse("MDC_C003"),
      )
      p2 = Cdd::Property.new(
        irdi: Cdd::IRDI.parse("AAAP002"),
        properties: { "MDC_P001_6" => "AAAP002", "MDC_P022" => "STRING_TYPE" },
        meta_class_irdi: Cdd::IRDI.parse("MDC_C003"),
      )
      p3 = Cdd::Property.new(
        irdi: Cdd::IRDI.parse("AAAP003"),
        properties: { "MDC_P001_6" => "AAAP003", "MDC_P022" => "STRING_TYPE" },
        meta_class_irdi: Cdd::IRDI.parse("MDC_C003"),
      )
      [parent, child, p1, p2, p3].each { |e| d.add_entity(e) }
      d.finalize!
    end
  end

  it "renames the target's own code and IRDI" do
    db.rename_entity("AAA001", "AAA999")
    target = db.find_by_code("AAA999")
    expect(target).not_to be_nil
    expect(target.irdi.code).to eq("AAA999")
    expect(target["MDC_P001_5"]).to eq("AAA999")
  end

  it "removes the old code from lookups" do
    db.rename_entity("AAA001", "AAA999")
    expect(db.find_by_code("AAA001")).to be_nil
    expect(db.find(target_irdi("AAA001"))).to be_nil
  end

  it "rewrites identifier_ref back-references (MDC_P010 superclass)" do
    db.rename_entity("AAA001", "AAA999")
    child = db.find_by_code("AAA002")
    expect(child["MDC_P010"]).to eq("AAA999")
  end

  it "rewrites set_of_refs back-references (MDC_P013 is_case_of)" do
    db.rename_entity("AAA001", "AAA999")
    child = db.find_by_code("AAA002")
    expect(Cdd::ParseHelpers.parse_irdi_list(child["MDC_P013"]).map(&:code))
      .to contain_exactly("AAA999")
  end

  it "rewrites definition_class back-references on properties (MDC_P021)" do
    db.rename_entity("AAA001", "AAA999")
    p1 = db.find_by_code("AAAP001")
    expect(p1["MDC_P021"]).to eq("AAA999")
  end

  it "is idempotent when old_code equals new_code" do
    before = db.find_by_code("AAA001").irdi
    db.rename_entity("AAA001", "AAA001")
    expect(db.find_by_code("AAA001").irdi).to eq(before)
  end

  it "is a no-op when old_code is unknown" do
    expect { db.rename_entity("UNKNOWN", "XXX") }.not_to change { db.entities.size }
    expect(db.find_by_code("XXX")).to be_nil
  end

  it "warns and refuses to overwrite when target code is in use" do
    expect { db.rename_entity("AAA001", "AAA002") }.to output(/already in use/).to_stderr
    expect(db.find_by_code("AAA001")).not_to be_nil
    expect(db.find_by_code("AAA002").irdi.code).to eq("AAA002")
  end

  it "preserves the symbol table for renamed entities" do
    db.rename_entity("AAA001", "AAA999")
    expect(db.resolve_reference("AAA999")).not_to be_nil
  end

  def target_irdi(code)
    Cdd::IRDI.parse(code)
  end
end
