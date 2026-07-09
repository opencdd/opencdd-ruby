# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::InstanceRule do
  let(:klass) { Cdd::Klass.new(irdi: Cdd::IRDI.parse("AAA001"), properties: {}, meta_class_irdi: Cdd::IRDI.parse("MDC_C002")) }

  def group(name, props)
    described_class::Group.new(name: name, values_by_property: props)
  end

  def exception(name, line)
    described_class::Exception.new(group_name: name, line_id: line)
  end

  it "expands one group of 3 values into 3 instances" do
    rule = described_class.new(
      klass: klass,
      groups: [group("engine", { "engine_type" => %w[diesel petrol electric] })],
    )
    rows = rule.expand
    expect(rows.size).to eq(3)
    expect(rows.map { |r| r["engine_type"] }).to eq(%w[diesel petrol electric])
  end

  it "cross-multiplies two groups (2 x 3 = 6)" do
    rule = described_class.new(
      klass: klass,
      groups: [
        group("engine", { "engine_type" => %w[diesel petrol] }),
        group("colour", { "colour" => %w[red green blue] }),
      ],
    )
    rows = rule.expand
    expect(rows.size).to eq(6)
  end

  it "cross-multiplies three groups (2 x 3 x 2 = 12)" do
    rule = described_class.new(
      klass: klass,
      groups: [
        group("engine", { "engine_type" => %w[diesel petrol] }),
        group("colour", { "colour" => %w[red green blue] }),
        group("trim",   { "trim" => %w[standard premium] }),
      ],
    )
    rows = rule.expand
    expect(rows.size).to eq(12)
  end

  it "correlates values within a group (positional, not cross-multiplied)" do
    rule = described_class.new(
      klass: klass,
      groups: [
        group("engine", { "engine_type" => %w[diesel petrol], "cylinders" => %w[4 6] }),
      ],
    )
    rows = rule.expand
    expect(rows.size).to eq(2)
    expect(rows[0]["engine_type"]).to eq("diesel")
    expect(rows[0]["cylinders"]).to eq("4")
    expect(rows[1]["engine_type"]).to eq("petrol")
    expect(rows[1]["cylinders"]).to eq("6")
  end

  it "removes one row per exception" do
    rule = described_class.new(
      klass: klass,
      groups: [group("engine", { "engine_type" => %w[diesel petrol electric] })],
      exceptions: [exception("engine", "LINE2")],
    )
    rows = rule.expand
    expect(rows.size).to eq(2)
    expect(rows.map { |r| r["engine_type"] }).to eq(%w[diesel electric])
  end

  it "returns zero instances if one group has zero candidates" do
    rule = described_class.new(
      klass: klass,
      groups: [
        group("engine", { "engine_type" => %w[diesel petrol] }),
        group("colour", { "colour" => [] }),
      ],
    )
    expect(rule.expand.size).to eq(0)
  end

  it "returns zero instances if groups is empty" do
    rule = described_class.new(klass: klass, groups: [])
    expect(rule.expand).to eq([])
  end

  it "strips internal bookkeeping from output rows" do
    rule = described_class.new(
      klass: klass,
      groups: [group("engine", { "engine_type" => %w[diesel] })],
    )
    rows = rule.expand
    expect(rows.first.keys).to eq(["engine_type"])
  end
end
