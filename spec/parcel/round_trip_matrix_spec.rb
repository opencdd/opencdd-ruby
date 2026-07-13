# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# Formal round-trip test matrix (plan 12 + 25). Each cell of the
# matrix is one example: source fixture → transformation → assert
# semantic equality.
#
# A failing cell here is a regression — usually a sign that the
# CDDAL builder, Parcel writer, or Parcel reader has drifted from
# the canonical model.

RSpec.describe "Round-trip matrix", :round_trip do
  let(:oceanrunner_path) { REFERENCE_DOCS.join("examples/oceanrunner.cddal") }
  let(:kagoshima_path)   { REFERENCE_DOCS.join("202003-kagoshima-iec-def-sample.cddal") }

  let(:oceanrunner) { Opencdd::Cddal.parse_file(oceanrunner_path.to_s) }
  let(:kagoshima)   { Opencdd::Cddal.parse_file(kagoshima_path.to_s) }

  # A synthetic per-type fixture: one of each entity type we model
  # (Class, Property, Unit, ValueList, ValueTerm, Relation). Catches
  # type-specific drift the OceanRunner fixture (which is class-heavy)
  # might miss.
  let(:synthetic_per_type) do
    Opencdd::Cddal.parse(<<~CDDAL)
      meta-class MDC_C002 { code preferred_name class_type }
      meta-class MDC_C003 { code preferred_name definition_class data_type }
      meta-class MDC_C005 { code preferred_name enumerated_values }
      meta-class MDC_C009 { code preferred_name }
      meta-class MDC_C010 { code preferred_name }
      meta-class MDC_C011 { code preferred_name relation_type }

      instance Vehicle < MDC_C002 {
        code: AAA001
        preferred_name.en: "Vehicle"
        class_type: ITEM_CLASS
      }
      instance vehicle_length < MDC_C003 {
        code: AAAP001
        preferred_name.en: "vehicle length"
        definition_class: Vehicle
        data_type: REAL_TYPE
      }
      instance mode_enum < MDC_C005 {
        code: AAAE001
        preferred_name.en: "operating mode"
        enumerated_values: { ROAD, WATER }
      }
      instance metre < MDC_C009 {
        code: UAC001
        preferred_name.en: "metre"
      }
      instance road_term < MDC_C010 {
        code: AQA001
        preferred_name.en: "road"
      }
      instance rel_length_to_class < MDC_C011 {
        code: AAR001
        preferred_name.en: "length→vehicle"
        relation_type: PREDICATION
      }
    CDDAL
  end

  # Helpers ------------------------------------------------------------

  def with_tmp_xlsx
    Dir.mktmpdir("rt-matrix") do |dir|
      path = File.join(dir, "matrix.xlsx")
      yield path
    end
  end

  def write_then_read(db, parcel_id:)
    with_tmp_xlsx do |path|
      Opencdd::Parcel::Writer.new(db).write(path, parcel_id: parcel_id)
      Opencdd::Database.load(path)
    end
  end

  # CDDAL → CDDAL ----------------------------------------------------

  describe "CDDAL → CDDAL (parse → serialize → parse)" do
    it "preserves OceanRunner" do
      out = Opencdd::Cddal.serialize(oceanrunner)
      db2 = Opencdd::Cddal.parse(out)
      expect(oceanrunner.semantically_equal?(db2)).to be(true)
    end

    it "preserves Kagoshima" do
      out = Opencdd::Cddal.serialize(kagoshima)
      db2 = Opencdd::Cddal.parse(out)
      expect(kagoshima.semantically_equal?(db2)).to be(true)
    end

    it "preserves the synthetic per-type fixture" do
      out = Opencdd::Cddal.serialize(synthetic_per_type)
      db2 = Opencdd::Cddal.parse(out)
      expect(synthetic_per_type.semantically_equal?(db2)).to be(true)
    end
  end

  # CDDAL → Parcel → CDDAL ------------------------------------------

  describe "CDDAL → Parcel → CDDAL" do
    it "preserves OceanRunner (40 entities, 20 classes, 19 properties, 1 value_list)" do
      reread = write_then_read(oceanrunner, parcel_id: "OCEAN")
      expect(reread.entities.size).to eq(oceanrunner.entities.size)
      expect(reread.classes.size).to eq(oceanrunner.classes.size)
      expect(reread.properties.size).to eq(oceanrunner.properties.size)
      expect(reread.value_lists.size).to eq(oceanrunner.value_lists.size)
    end

    it "preserves Kagoshima" do
      reread = write_then_read(kagoshima, parcel_id: "KAGOSHIMA")
      expect(reread.entities.size).to eq(kagoshima.entities.size)
    end

    it "preserves every entity type in the synthetic fixture" do
      reread = write_then_read(synthetic_per_type, parcel_id: "SYNTH")
      expect(reread.classes.size).to eq(synthetic_per_type.classes.size)
      expect(reread.properties.size).to eq(synthetic_per_type.properties.size)
      expect(reread.units.size).to eq(synthetic_per_type.units.size)
      expect(reread.value_lists.size).to eq(synthetic_per_type.value_lists.size)
      expect(reread.value_terms.size).to eq(synthetic_per_type.value_terms.size)
      expect(reread.relations.size).to eq(synthetic_per_type.relations.size)
    end

    it "preserves property codes on Property entities (the P24 regression)" do
      reread = write_then_read(synthetic_per_type, parcel_id: "SYNTH")
      prop = reread.properties.find { |p| p.code == "AAAP001" }
      expect(prop).not_to be_nil
      expect(prop.preferred_name).to eq("vehicle length")
    end
  end

  # CDDAL → JSON → CDDAL --------------------------------------------

  describe "CDDAL → JSON → CDDAL" do
    it "preserves OceanRunner" do
      skip "JSON exporter is a one-way serializer; round-trip requires a JSON importer (out of scope for v1)"
    end
  end

  # Parcel (synthesized) → CDDAL → Parcel ---------------------------

  describe "Parcel (synthesized) → CDDAL → Parcel preserves entity counts" do
    it "round-trips a synthetic Class-only workbook through CDDAL" do
      db = Opencdd::Database.new
      klass = Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse("0112/2///61360_4#AAA001"),
        properties: {
          "MDC_P001_5"  => "0112/2///61360_4#AAA001",
          "MDC_P004.en" => "Round-trip class",
          "MDC_P011"    => "ITEM_CLASS",
        },
        meta_class_irdi: Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
      )
      db.add_entity(klass)
      db.finalize!

      reread = write_then_read(db, parcel_id: "ROUNDTRIP")
      expect(reread.classes.size).to eq(1)
      expect(reread.classes.first.code).to eq("AAA001")
    end
  end
end
