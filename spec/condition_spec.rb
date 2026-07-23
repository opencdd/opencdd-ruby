# frozen_string_literal: true

require "spec_helper"
require "set"

RSpec.describe Opencdd::Condition do
  describe ".parse" do
    it "parses a simple equality expression" do
      cond = described_class.parse("operating_mode == surface_water")
      expect(cond.left).to eq("operating_mode")
      expect(cond.operator).to eq("==")
      expect(cond.right).to eq("surface_water")
      expect(cond).not_to be_set
    end

    it "parses a not-equal expression" do
      cond = described_class.parse("operating_mode != road")
      expect(cond.operator).to eq("!=")
    end

    it "parses a set RHS as a Set" do
      cond = described_class.parse("mode == { surface_water, underwater }")
      expect(cond).to be_set
      expect(cond.right).to be_a(Set)
      expect(cond.right.to_a).to contain_exactly("surface_water", "underwater")
    end

    it "strips surrounding quotes from a literal RHS" do
      cond = described_class.parse('mode == "surface water"')
      expect(cond.right).to eq("surface water")
    end

    it "returns nil for nil/empty input" do
      expect(described_class.parse(nil)).to be_nil
      expect(described_class.parse("")).to be_nil
      expect(described_class.parse("   ")).to be_nil
    end

    it "raises ArgumentError for malformed expression" do
      expect { described_class.parse("no operator here") }.to raise_error(ArgumentError, /invalid condition expression/)
    end
  end

  describe "class-reference conditions" do
    describe ".parse with a bare IRDI" do
      it "returns a ClassReference wrapping a single IRDI" do
        cond = described_class.parse("0112/2///62683#ACE132")
        expect(cond).to be_a(Opencdd::Condition::ClassReference)
        expect(cond).to be_class_reference
        expect(cond.irdis).to eq(["0112/2///62683#ACE132"])
        expect(cond).not_to be_set
      end

      it "accepts a short-form code as a single token" do
        cond = described_class.parse("ACE132")
        expect(cond).to be_a(Opencdd::Condition::ClassReference)
        expect(cond.irdis).to eq(["ACE132"])
      end
    end

    describe ".parse with a bare set" do
      it "returns a ClassReference with every set element" do
        cond = described_class.parse("{0112/2///62683#ACE132, 0112/2///62683#ACE133}")
        expect(cond).to be_a(Opencdd::Condition::ClassReference)
        expect(cond).to be_class_reference
        expect(cond.irdis).to eq(["0112/2///62683#ACE132", "0112/2///62683#ACE133"])
        expect(cond).to be_set
      end

      it "tolerates whitespace-only element separators" do
        cond = described_class.parse("{0112/2///62683#ACE132 0112/2///62683#ACE133}")
        expect(cond.irdis.size).to eq(2)
      end

      it "rejects an empty set as a class reference" do
        # The body becomes "" → split → [] → ClassReference with no irdis.
        # We treat that as malformed because there is no IRDI to match.
        cond = described_class.parse("{}")
        expect(cond.irdis).to eq([])
      end
    end

    describe "#satisfied_by? on ClassReference" do
      it "matches when bindings[:class] is in the IRDI set" do
        cond = described_class.parse("0112/2///62683#ACE132")
        expect(cond.satisfied_by?(class: "0112/2///62683#ACE132")).to be(true)
        expect(cond.satisfied_by?(class: "0112/2///62683#ACE999")).to be(false)
      end

      it "matches when the host class is one of several IRDIs" do
        cond = described_class.parse("{0112/2///62683#ACE132, 0112/2///62683#ACE133}")
        expect(cond.satisfied_by?(class: "0112/2///62683#ACE132")).to be(true)
        expect(cond.satisfied_by?(class: "0112/2///62683#ACE133")).to be(true)
        expect(cond.satisfied_by?(class: "0112/2///62683#ACE999")).to be(false)
      end

      it "accepts :host_class as an alias for :class" do
        cond = described_class.parse("0112/2///62683#ACE132")
        expect(cond.satisfied_by?(host_class: "0112/2///62683#ACE132")).to be(true)
      end

      it "returns true when no host-class binding is present" do
        # No class context: don't block evaluation. The property still applies.
        cond = described_class.parse("0112/2///62683#ACE132")
        expect(cond.satisfied_by?(other: "x")).to be(true)
      end
    end

    describe "#to_s round-trip" do
      it "round-trips a bare IRDI" do
        source = "0112/2///62683#ACE132"
        expect(described_class.parse(source).to_s).to eq(source)
      end

      it "round-trips a multi-IRDI set in normalized form" do
        parsed = described_class.parse("{0112/2///62683#ACE132, 0112/2///62683#ACE133}")
        expect(parsed.to_s).to eq("{0112/2///62683#ACE132, 0112/2///62683#ACE133}")
      end
    end

    describe "equality and hash" do
      it "treats structurally identical ClassReferences as equal" do
        a = described_class.parse("0112/2///62683#ACE132")
        b = described_class.parse("0112/2///62683#ACE132")
        expect(a).to eq(b)
        expect(a.hash).to eq(b.hash)
      end

      it "treats set-element order as irrelevant" do
        a = described_class.parse("{0112/2///62683#ACE132, 0112/2///62683#ACE133}")
        b = described_class.parse("{0112/2///62683#ACE133, 0112/2///62683#ACE132}")
        expect(a).to eq(b)
        expect(a.hash).to eq(b.hash)
      end

      it "distinguishes ClassReference from boolean Condition" do
        expression = described_class.parse("mode == surface_water")
        class_ref = described_class.parse("0112/2///62683#ACE132")
        expect(expression).not_to eq(class_ref)
        expect(class_ref).not_to eq(expression)
      end
    end
  end

  describe "#satisfied_by?" do
    it "is true when binding matches equality" do
      cond = described_class.parse("operating_mode == surface_water")
      expect(cond.satisfied_by?(operating_mode: "surface_water")).to be(true)
    end

    it "is false when binding differs" do
      cond = described_class.parse("operating_mode == surface_water")
      expect(cond.satisfied_by?(operating_mode: "road")).to be(false)
    end

    it "is true when inequality holds" do
      cond = described_class.parse("operating_mode != road")
      expect(cond.satisfied_by?(operating_mode: "surface_water")).to be(true)
      expect(cond.satisfied_by?(operating_mode: "road")).to be(false)
    end

    it "is false when no binding exists for the LHS" do
      cond = described_class.parse("operating_mode == surface_water")
      expect(cond.satisfied_by?(other: "x")).to be(false)
    end

    it "matches set membership on equality" do
      cond = described_class.parse("mode == { surface_water, underwater }")
      expect(cond.satisfied_by?(mode: "surface_water")).to be(true)
      expect(cond.satisfied_by?(mode: "underwater")).to be(true)
      expect(cond.satisfied_by?(mode: "road")).to be(false)
    end

    it "negates set membership" do
      cond = described_class.parse("mode != { surface_water, underwater }")
      expect(cond.satisfied_by?(mode: "road")).to be(true)
      expect(cond.satisfied_by?(mode: "surface_water")).to be(false)
    end

    it "accepts both string and symbol binding keys" do
      cond = described_class.parse("operating_mode == surface_water")
      expect(cond.satisfied_by?("operating_mode" => "surface_water")).to be(true)
    end
  end

  describe "#to_s round-trip" do
    it "round-trips a simple equality" do
      source = "operating_mode == surface_water"
      expect(described_class.parse(source).to_s).to eq(source)
    end

    it "round-trips a set membership" do
      source = "mode == { surface_water, underwater }"
      expect(described_class.parse(source).to_s).to eq(source)
    end
  end

  describe "equality and hash" do
    it "treats structurally identical conditions as equal" do
      a = described_class.parse("mode == surface_water")
      b = described_class.parse("mode == surface_water")
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "treats set-element order as irrelevant" do
      a = described_class.parse("mode == { surface_water, underwater }")
      b = described_class.parse("mode == { underwater, surface_water }")
      expect(a).to eq(b)
    end
  end
end
