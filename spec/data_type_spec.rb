# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::DataType do
  describe ".parse for simple types" do
    it "parses STRING_TYPE" do
      dt = described_class.parse("STRING_TYPE")
      expect(dt).to be_a(described_class)
      expect(dt.kind).to eq("STRING_TYPE")
      expect(dt).to be_simple
      expect(dt).not_to be_measure
      expect(dt).not_to be_reference
      expect(dt).not_to be_parameterized
    end

    it "parses REAL_TYPE, INT_TYPE, BOOLEAN_TYPE, DATE_TYPE, IRDI_TYPE" do
      %w[REAL_TYPE INT_TYPE BOOLEAN_TYPE DATE_TYPE IRDI_TYPE].each do |k|
        dt = described_class.parse(k)
        expect(dt.kind).to eq(k)
        expect(dt).to be_simple
      end
    end
  end

  describe ".parse for measure types" do
    it "parses REAL_MEASURE_TYPE as a RealMeasureType subclass" do
      dt = described_class.parse("REAL_MEASURE_TYPE")
      expect(dt).to be_a(Cdd::DataType::RealMeasureType)
      expect(dt).to be_measure
      expect(dt.to_s).to eq("REAL_MEASURE_TYPE")
    end

    it "parses INTEGER_MEASURE_TYPE" do
      dt = described_class.parse("INTEGER_MEASURE_TYPE")
      expect(dt).to be_a(Cdd::DataType::IntegerMeasureType)
      expect(dt).to be_measure
    end

    it "accepts INT_MEASURE_TYPE as an alias for INTEGER_MEASURE_TYPE" do
      dt = described_class.parse("INT_MEASURE_TYPE")
      expect(dt).to be_a(Cdd::DataType::IntegerMeasureType)
    end
  end

  describe ".parse for parameterized types" do
    it "parses CLASS_REFERENCE(EngineType)" do
      dt = described_class.parse("CLASS_REFERENCE(EngineType)")
      expect(dt).to be_a(Cdd::DataType::ClassReference)
      expect(dt.class_identifier).to eq("EngineType")
      expect(dt).to be_class_reference
      expect(dt).to be_reference
      expect(dt).to be_parameterized
      expect(dt.to_s).to eq("CLASS_REFERENCE(EngineType)")
    end

    it "parses ENUM_STRING_TYPE(vehicle_mode_enum)" do
      dt = described_class.parse("ENUM_STRING_TYPE(vehicle_mode_enum)")
      expect(dt).to be_a(Cdd::DataType::EnumStringType)
      expect(dt.value_list_identifier).to eq("vehicle_mode_enum")
      expect(dt).to be_enum
      expect(dt).to be_reference
      expect(dt.to_s).to eq("ENUM_STRING_TYPE(vehicle_mode_enum)")
    end

    it "parses ENUM_REFERENCE_TYPE(vehicle_mode_enum)" do
      dt = described_class.parse("ENUM_REFERENCE_TYPE(vehicle_mode_enum)")
      expect(dt).to be_a(Cdd::DataType::EnumReferenceType)
      expect(dt.value_list_identifier).to eq("vehicle_mode_enum")
      expect(dt).to be_enum
    end

    it "tolerates whitespace inside the parameter list" do
      dt = described_class.parse("CLASS_REFERENCE(  Foo  )")
      expect(dt.class_identifier).to eq("Foo")
    end
  end

  describe ".parse error handling" do
    it "raises ArgumentError for unknown simple type" do
      expect { described_class.parse("UNKNOWN_TYPE") }.to raise_error(ArgumentError, /unknown data_type/)
    end

    it "returns nil for nil/empty input" do
      expect(described_class.parse(nil)).to be_nil
      expect(described_class.parse("")).to be_nil
      expect(described_class.parse("   ")).to be_nil
    end
  end

  describe ".parse_or_string" do
    it "parses known types" do
      expect(described_class.parse_or_string("REAL_TYPE")).to be_a(described_class)
    end

    it "falls back to the raw string for unknown types" do
      expect(described_class.parse_or_string("UNKNOWN_TYPE")).to eq("UNKNOWN_TYPE")
    end
  end

  describe "equality and hash" do
    it "treats equal parsed types as equal" do
      a = described_class.parse("CLASS_REFERENCE(Vehicle)")
      b = described_class.parse("CLASS_REFERENCE(Vehicle)")
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "distinguishes different arguments" do
      a = described_class.parse("CLASS_REFERENCE(Vehicle)")
      b = described_class.parse("CLASS_REFERENCE(Boat)")
      expect(a).not_to eq(b)
    end
  end
end
