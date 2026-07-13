# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::StructuredValues do
  describe "synonyms" do
    it "parses brace-wrapped tuples" do
      result = described_class.parse_synonyms("{(a,en),(b,fr)}")
      expect(result).to eq([["en", "a"], ["fr", "b"]])
    end

    it "parses legacy paren form without braces" do
      result = described_class.parse_synonyms('(a,en),(b,fr)')
      expect(result).to eq([["en", "a"], ["fr", "b"]])
    end

    it "returns empty for nil or blank" do
      expect(described_class.parse_synonyms(nil)).to eq([])
      expect(described_class.parse_synonyms("")).to eq([])
    end

    it "round-trips through serialize" do
      pairs = [["en", "Hello"], ["fr", "Bonjour"]]
      serialized = described_class.serialize_synonyms(pairs)
      parsed = described_class.parse_synonyms(serialized)
      expect(parsed).to eq(pairs)
    end

    it "serializes to canonical brace form" do
      expect(described_class.serialize_synonyms([["en", "a"], ["fr", "b"]]))
        .to eq('{(a,en),(b,fr)}')
    end
  end

  describe "ref_set" do
    it "parses brace-wrapped IRDI list" do
      result = described_class.parse_ref_set("{0112/2///62683#ACE001,0112/2///62683#ACE002}")
      expect(result.map(&:to_s)).to eq(["0112/2///62683#ACE001", "0112/2///62683#ACE002"])
    end

    it "returns empty for nil" do
      expect(described_class.parse_ref_set(nil)).to eq([])
    end

    it "round-trips through serialize" do
      irdis = [Opencdd::IRDI.parse("0112/2///62683#ACE001"), Opencdd::IRDI.parse("0112/2///62683#ACE002")]
      serialized = described_class.serialize_ref_set(irdis)
      parsed = described_class.parse_ref_set(serialized)
      expect(parsed).to eq(irdis)
    end

    it "serializes to canonical brace form" do
      irdi = Opencdd::IRDI.parse("0112/2///62683#ACE001")
      expect(described_class.serialize_ref_set([irdi])).to eq("{0112/2///62683#ACE001}")
    end
  end

  describe "class_ref" do
    it "parses a single IRDI" do
      result = described_class.parse_class_ref("0112/2///62683#ACE001")
      expect(result).to eq(Opencdd::IRDI.parse("0112/2///62683#ACE001"))
    end

    it "returns nil for blank" do
      expect(described_class.parse_class_ref(nil)).to be_nil
      expect(described_class.parse_class_ref("")).to be_nil
    end

    it "serializes an IRDI" do
      irdi = Opencdd::IRDI.parse("0112/2///62683#ACE001")
      expect(described_class.serialize_class_ref(irdi)).to eq("0112/2///62683#ACE001")
    end
  end

  describe "data_type" do
    it "parses a simple type" do
      result = described_class.parse_data_type("STRING_TYPE")
      expect(result.to_s).to eq("STRING_TYPE")
    end

    it "parses CLASS_REFERENCE" do
      result = described_class.parse_data_type("CLASS_REFERENCE(0112/2///62683#ACC001)")
      expect(result.class_reference?).to be(true)
      expect(result.class_identifier).to eq("0112/2///62683#ACC001")
    end

    it "serializes through to_s" do
      dt = Opencdd::DataType.parse("REAL_TYPE")
      expect(described_class.serialize_data_type(dt)).to eq("REAL_TYPE")
    end
  end

  describe "condition" do
    it "parses an expression" do
      result = described_class.parse_condition("MDC_P001_5 == \"ABC001\"")
      expect(result.left).to eq("MDC_P001_5")
      expect(result.operator).to eq("==")
    end

    it "returns nil for malformed input" do
      expect(described_class.parse_condition("just words no operator")).to be_nil
    end

    it "serializes through to_s" do
      cond = Opencdd::Condition.parse("MDC_P001_5 == ABC001")
      expect(described_class.serialize_condition(cond)).to eq("MDC_P001_5 == ABC001")
    end
  end

  describe "value_format" do
    it "parses NR3 S..7.7" do
      vf = described_class.parse_value_format("NR3 S..7.7")
      expect(vf.code).to eq("NR3")
      expect(vf.signed).to be(true)
      expect(vf.total).to eq(7)
      expect(vf.fractional).to eq(7)
    end

    it "parses M..255" do
      vf = described_class.parse_value_format("M..255")
      expect(vf.code).to eq("M")
      expect(vf.total).to eq(255)
    end

    it "round-trips NR1 S..8" do
      original = "NR1 S..8"
      vf = described_class.parse_value_format(original)
      expect(described_class.serialize_value_format(vf)).to eq(original)
    end

    it "returns nil for malformed" do
      expect(described_class.parse_value_format("XYZ")).to be_nil
    end
  end
end
