# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::Database, "#apply_view_control" do
  let(:db) do
    Cdd::Database.new.tap do |d|
      klass = Cdd::Klass.new(
        irdi: Cdd::IRDI.parse("AAA001"),
        properties: {
          "MDC_P001_5" => "AAA001",
          "MDC_P011"   => "ITEM_CLASS",
          "MDC_P014"   => "(AAAP001,AAAP002,AAAP003,AAAP004,AAAP005)",
        },
        meta_class_irdi: Cdd::IRDI.parse("MDC_C002"),
      )
      %w[AAAP001 AAAP002 AAAP003 AAAP004 AAAP005].each do |code|
        d.add_entity(Cdd::Property.new(
          irdi: Cdd::IRDI.parse(code),
          properties: { "MDC_P001_6" => code, "MDC_P022" => "STRING_TYPE" },
          meta_class_irdi: Cdd::IRDI.parse("MDC_C003"),
        ))
      end
      d.add_entity(klass)
      d.finalize!
    end
  end

  let(:klass) { db.find_by_code("AAA001") }

  def view_control(controlled_codes, shown_codes)
    Cdd::ViewControl.new(
      irdi: Cdd::IRDI.parse("EXT001"),
      properties: {
        "EXT_P001" => "EXT001",
        "EXT_P002" => "(#{controlled_codes.join(',')})",
        "EXT_P003" => "(#{shown_codes.join(',')})",
      },
      meta_class_irdi: Cdd::IRDI.parse("EXT_C001"),
    )
  end

  it "returns the filtered property list in shown order when the view applies" do
    vc = view_control(%w[AAA001], %w[AAAP003 AAAP001])
    result = db.apply_view_control(klass, vc)
    expect(result.map(&:code)).to eq(%w[AAAP003 AAAP001])
  end

  it "returns the full property list when the view does not list the class" do
    vc = view_control(%w[AAA999], %w[AAAP001])
    result = db.apply_view_control(klass, vc)
    expect(result.map(&:code)).to contain_exactly("AAAP001", "AAAP002", "AAAP003", "AAAP004", "AAAP005")
  end

  it "returns an empty list when shown_properties is empty" do
    vc = view_control(%w[AAA001], [])
    result = db.apply_view_control(klass, vc)
    expect(result).to eq([])
  end

  it "returns the full property list when view_control is nil" do
    result = db.apply_view_control(klass, nil)
    expect(result.size).to eq(5)
  end

  it "skips shown IRDIs that are not effective on the class" do
    vc = view_control(%w[AAA001], %w[AAAP001,UNKNOWN_CODE])
    result = db.apply_view_control(klass, vc)
    expect(result.map(&:code)).to eq(%w[AAAP001])
  end

  it "resolves the klass argument when given an IRDI" do
    vc = view_control(%w[AAA001], %w[AAAP001])
    result = db.apply_view_control(Cdd::IRDI.parse("AAA001"), vc)
    expect(result.map(&:code)).to eq(%w[AAAP001])
  end
end
