# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::IRDI do
  describe ".parse (full form)" do
    subject(:irdi) { described_class.parse("0112/2///61360_4#AAA001") }

    it { is_expected.to be_full }
    it { is_expected.not_to be_short }
    its(:registrant) { should eq("0112") }
    its(:semantic)   { should eq("2") }
    its(:scheme)     { should eq("61360_4") }
    its(:code)       { should eq("AAA001") }
    its(:short)      { should eq("AAA001") }
    its(:to_s)       { should eq("0112/2///61360_4#AAA001") }
    its(:to_tree_path) { should eq("0112-2---61360_4%23AAA001") }
    its(:sheetmap_version) { should be_nil }
  end

  describe ".parse (full form with sheetmap version)" do
    subject(:irdi) { described_class.parse("0112/2///62656_1#MDC_C002##1") }

    its(:code) { should eq("MDC_C002") }
    its(:sheetmap_version) { should eq("1") }
    its(:to_s) { should eq("0112/2///62656_1#MDC_C002") }
  end

  describe ".parse (short form)" do
    subject(:irdi) { described_class.parse("AAA001") }

    it { is_expected.to be_short }
    it { is_expected.not_to be_full }
    its(:code)       { should eq("AAA001") }
    its(:short)      { should eq("AAA001") }
    its(:to_s)       { should eq("AAA001") }
    its(:to_tree_path) { should eq("AAA001") }
  end

  describe ".parse (tree path)" do
    subject(:irdi) { described_class.parse("0112-2---61360_7%23AAS006") }

    it { is_expected.to be_full }
    its(:registrant) { should eq("0112") }
    its(:semantic)   { should eq("2") }
    its(:scheme)     { should eq("61360_7") }
    its(:code)       { should eq("AAS006") }
    its(:to_s)       { should eq("0112/2///61360_7#AAS006") }
    its(:to_tree_path) { should eq("0112-2---61360_7%23AAS006") }
  end

  describe ".parse (round-trip)" do
    [
      "0112/2///61360_4#AAA001",
      "0112/2///62656_1#MDC_C002##1",
      "AAA001",
      "0112-2---61360_7%23AAS006",
      "0112/2///62683#ACC001",
    ].each do |raw|
      it "#{raw.inspect} round-trips via to_s or to_tree_path" do
        irdi = described_class.parse(raw)
        expect(irdi).not_to be_nil
        round = raw.include?("%23") ? irdi.to_tree_path : irdi.to_s
        canonical = raw.sub(/##\d+\z/, "")
        expect(round).to eq(canonical)
      end
    end
  end

  describe ".parse (edge cases)" do
    it "returns nil for nil input" do
      expect(described_class.parse(nil)).to be_nil
    end

    it "returns nil for empty string" do
      expect(described_class.parse("")).to be_nil
    end

    it "returns nil for whitespace-only string" do
      expect(described_class.parse("   ")).to be_nil
    end
  end

  describe "equality" do
    it "considers same IRDI equal" do
      expect(described_class.parse("0112/2///61360_4#AAA001"))
        .to eq(described_class.parse("0112/2///61360_4#AAA001"))
    end

    it "considers IRDIs with different schemes unequal" do
      expect(described_class.parse("0112/2///61360_4#AAA001"))
        .not_to eq(described_class.parse("0112/2///61360_7#AAA001"))
    end

    it "treats full and tree-path forms of same IRDI as equal" do
      expect(described_class.parse("0112/2///61360_7#AAS006"))
        .to eq(described_class.parse("0112-2---61360_7%23AAS006"))
    end

    it "hashes equal IRDIs to the same value" do
      a = described_class.parse("0112/2///61360_4#AAA001")
      b = described_class.parse("0112/2///61360_4#AAA001")
      expect(a.hash).to eq(b.hash)
      expect([a] & [b]).to eq([a])
    end
  end

  describe "#with_code" do
    it "returns a new IRDI with the same scheme but different code" do
      base = described_class.parse("0112/2///61360_4#AAA001")
      derived = base.with_code("AAA002")
      expect(derived.to_s).to eq("0112/2///61360_4#AAA002")
      expect(base.to_s).to eq("0112/2///61360_4#AAA001")
    end
  end
end
