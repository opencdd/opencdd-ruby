# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Cdd::Cddal do
  let(:example_path) { REFERENCE_DOCS.join("examples/oceanrunner.cddal") }
  let(:database) { described_class.parse_file(example_path) }

  describe ".parse_file" do
    it "loads classes, properties, and value_lists from a CDDAL source" do
      expect(database.classes.size).to      eq(20)
      expect(database.properties.size).to   eq(19)
      expect(database.value_lists.size).to  eq(1)
    end

    it "registers aliases declared in the source" do
      expect(database.alias_table.resolve("superclass")).to eq("MDC_P010")
      expect(database.alias_table.resolve("data_type")).to eq("MDC_P022")
    end

    it "skips HTTPS imports (no in-page HTTP fetch is possible)" do
      text = <<~CDDAL
        import "https://example.invalid/dummy.cddal"
        instance Demo < MDC_C002 {
          code: DEMO001
          preferred_name.en: "Demo"
          class_type: ITEM_CLASS
        }
      CDDAL
      expect { described_class.parse(text) }.not_to raise_error
    end
  end

  describe "symbolic name resolution" do
    it "resolves symbolic instance names in superclass" do
      vehicle = database.find_by_code("AAA001")
      expect(vehicle.preferred_name).to eq("Vehicle")

      boat = database.find_by_code("AAA010")
      expect(boat.parent_irdi).to eq(vehicle.irdi)
      expect(boat.parent.code).to eq("AAA001")
    end

    it "resolves symbolic instance names in applicable_properties" do
      vehicle = database.find_by_code("AAA001")
      expect(vehicle.applicable_property_irdis.map(&:code)).to contain_exactly(
        "AAAP001", "AAAP002", "AAAP003",
      )
    end

    it "resolves is_case_of symbolic references" do
      tm = database.find_by_code("AAA100")
      expect(tm.is_case_of(database).map(&:code)).to contain_exactly(
        "AAA010", "AAA020", "AAA030",
      )
    end

    it "resolves definition_class to a Klass on each Property" do
      prop = database.find_by_code("AAAP010")
      expect(prop.definition_class_irdi.code).to eq("AAA010")
    end

    it "resolves sub_class_selection to categorical instances" do
      configured = database.find_by_code("BBB100")
      expect(configured.sub_class_selection(database).map(&:code)).to contain_exactly(
        "AAA202", "AAA212", "AAA222",
      )
    end
  end

  describe "class_type semantics" do
    it "marks categorical classes correctly" do
      engine_type = database.find_by_code("AAA200")
      expect(engine_type).to be_categorical
      expect(engine_type.class_type.to_s).to eq("CATEGORICAL_CLASS")
    end

    it "marks item classes correctly" do
      vehicle = database.find_by_code("AAA001")
      expect(vehicle).to be_item
    end
  end

  describe "data_type semantics" do
    it "parses CLASS_REFERENCE data types" do
      prop = database.find_by_code("BBAP001")
      expect(prop).to be_class_reference
      expect(prop.parsed_data_type.class_identifier).to eq("EngineType")
    end

    it "parses ENUM_STRING_TYPE data types" do
      prop = database.find_by_code("AAAP100")
      expect(prop).to be_enum
      expect(prop.parsed_data_type.value_list_identifier).to eq("vehicle_mode_enum")
    end

    it "parses simple REAL_TYPE data types" do
      prop = database.find_by_code("AAAP001")
      expect(prop.parsed_data_type.to_s).to eq("REAL_TYPE")
    end
  end

  describe "conditional properties" do
    it "marks CONDITION_DET properties as conditional" do
      prop = database.find_by_code("AAAP101")
      expect(prop).to be_conditional
      expect(prop.condition.to_s).to eq("operating_mode == surface_water")
    end

    it "marks NON_DEPENDENT_P_DET properties as non-conditional" do
      prop = database.find_by_code("AAAP001")
      expect(prop).not_to be_conditional
    end

    it "evaluates the condition against a binding hash" do
      surface_speed = database.find_by_code("AAAP101")
      expect(surface_speed.active_for?(operating_mode: "surface_water")).to be(true)
      expect(surface_speed.active_for?(operating_mode: "road")).to be(false)
    end
  end

  describe ".serialize" do
    it "round-trips parse -> serialize -> parse with semantic equality" do
      text = described_class.serialize(database)
      reparsed = described_class.parse(text)
      expect(reparsed.semantically_equal?(database)).to be(true)
    end

    it "emits aliases for the well-known property ids" do
      text = described_class.serialize(database)
      expect(text).to include("alias superclass: MDC_P010")
      expect(text).to include("alias data_type: MDC_P022")
      expect(text).to include("alias unit: MDC_P041")
    end
  end

  describe ".serialize_to_file" do
    it "writes the CDDAL to the given path and returns the module" do
      target = Tempfile.new(["cddal-spec", ".cddal"])
      target.close
      begin
        result = described_class.serialize_to_file(database, target.path)
        expect(result).to equal(described_class)
        reloaded = described_class.parse_file(target.path)
        expect(reparsed_equal = reloaded.semantically_equal?(database)).to be(true)
      ensure
        target.unlink
      end
    end
  end

  describe "error classes" do
    it "exposes Error, LexError, ParseError, ResolutionError" do
      expect(described_class::Error).to be < StandardError
      expect(described_class::LexError).to be < described_class::Error
      expect(described_class::ParseError).to be < described_class::Error
      expect(described_class::ResolutionError).to be < described_class::Error
    end

    it "raises LexError on an unexpected character" do
      expect { described_class.parse("instance Foo < MDC_C002 { @ }") }
        .to raise_error(Cdd::Cddal::LexError, /unexpected character/)
    end

    it "raises ParseError when an alias is missing its target" do
      expect { described_class.parse("alias foo") }
        .to raise_error(Cdd::Cddal::ParseError)
    end
  end
end

RSpec.describe "Cdd::Database#semantically_equal?" do
  it "compares two databases parsed from the same source as equal" do
    path = REFERENCE_DOCS.join("examples/oceanrunner.cddal")
    a = Cdd::Cddal.parse_file(path)
    b = Cdd::Cddal.parse_file(path)
    expect(a.semantically_equal?(b)).to be(true)
  end

  it "detects inequality when one database is missing entities" do
    path = REFERENCE_DOCS.join("examples/oceanrunner.cddal")
    a = Cdd::Cddal.parse_file(path)
    b = Cdd::Database.new
    expect(a.semantically_equal?(b)).to be(false)
  end
end

RSpec.describe "Parcel xlsx → CDDAL round-trip" do
  it "round-trips the ParcelMaker nuts example through CDDAL with semantic equality" do
    db1 = Cdd::Parcel::WorkbookReader.new(NUTS_XLSX.to_s).load_into(Cdd::Database.new)
    cddal = Cdd::Cddal.serialize(db1)
    db2 = Cdd::Cddal.parse(cddal)
    expect(db1.semantically_equal?(db2)).to be(true)
  end
end

RSpec.describe "Kagoshima IEC DEF sample" do
  it "parses hyphenated meta-class keywords" do
    db = Cdd::Cddal.parse_file(KAGOSHIMA_CDDAL)
    expect(db.entities.size).to eq(6)
  end

  it "supports anonymous instances (instance < META_CLASS without name)" do
    db = Cdd::Cddal.parse_file(KAGOSHIMA_CDDAL)
    expect(db.classes.size).to eq(1)
    expect(db.properties.size).to eq(2)
    expect(db.value_lists.size).to eq(1)
    expect(db.value_terms.size).to eq(2)
  end

  it "round-trips through serialize → parse with semantic equality" do
    db1 = Cdd::Cddal.parse_file(KAGOSHIMA_CDDAL)
    cddal = Cdd::Cddal.serialize(db1)
    db2 = Cdd::Cddal.parse(cddal)
    expect(db1.semantically_equal?(db2)).to be(true)
  end
end
