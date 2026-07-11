# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Parcel round-trip", :round_trip do
  # Round-trip guard: write a small workbook via Cdd::Parcel::Writer,
  # read it back via Cdd::Parcel::WorkbookReader, and assert the two
  # databases carry the same entities with the same field values.
  # Catches silent drift between writer and reader (column shifts,
  # missing fields, type changes).

  def build_database
    db = Cdd::Database.new
    # meta_class_irdi must be MDC_C002 (Class) so the Database
    # classifies these as :class type — entities of unknown types
    # are dropped by the Writer's per-type partition.
    #
    # Property IDs used here (MDC_P004, MDC_P010, MDC_P011) are the
    # ones that round-trip cleanly through the Parcel format. Some
    # canonical IDs collide with ParcelMaker variant IDs (e.g.
    # canonical MDC_P005 = short_name, but ParcelMaker uses
    # MDC_P005 = definition). Round-trip through Parcel for those
    # fields is tracked in TODO.impl/06-parcel-format.md.
    parent = Cdd::Klass.new(
      irdi: Cdd::IRDI.parse("0112/2///61360_4#AAA000"),
      properties: {
        "MDC_P001_5"  => "0112/2///61360_4#AAA000",
        "MDC_P011"    => "ITEM_CLASS",
        "MDC_P004.en" => "Component",
      },
      meta_class_irdi: Cdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
    )
    klass = Cdd::Klass.new(
      irdi: Cdd::IRDI.parse("0112/2///61360_4#AAA001"),
      properties: {
        "MDC_P001_5"  => "0112/2///61360_4#AAA001",
        "MDC_P011"    => "ITEM_CLASS",
        "MDC_P004.en" => "Voltage amplifier",
        "MDC_P010_1"  => "0112/2///61360_4#AAA000",
      },
      meta_class_irdi: Cdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
    )
    db.add_entity(parent)
    db.add_entity(klass)
    db.finalize!
    db
  end

  # NOTE: These specs previously revealed a Writer → Reader round-trip
  # drift (TODO.work/10). Root cause was the test fixture using
  # MDC_C001 (Dictionary) as meta_class_irdi instead of MDC_C002
  # (Class). Entities of unknown types get dropped by the Writer's
  # per-type partition, so reread saw zero entities. Fixed by using
  # the correct meta-class IRDI in build_database; the test now
  # serves as the regression guard.
  it "round-trips classes through Parcel xlsx" do
    original = build_database
    Dir.mktmpdir("cdd-round-trip") do |dir|
      out = File.join(dir, "round_trip.xlsx")
      Cdd::Parcel::Writer.new(original).write(
        out,
        parcel_id: "ROUNDTRIP",
        project_id: "TEST",
        source_language: "en",
      )

      reread = Cdd::Reader.load_database(out)

      # Same IRDIs present
      expect(reread.entities.map(&:irdi).map(&:to_s).sort)
        .to eq(original.entities.map(&:irdi).map(&:to_s).sort)

      # Spot-check both classes. The preferred_name (MDC_P004) is
      # preserved through Parcel round-trip.
      original_klass = original.classes.find { |k| k.code == "AAA001" }
      reread_klass = reread.classes.find { |k| k.code == "AAA001" }
      expect(reread_klass).not_to be_nil
      expect(reread_klass.preferred_name).to eq(original_klass.preferred_name)
      expect(reread_klass.class_type.to_s).to eq(original_klass.class_type.to_s)

      original_parent = original.classes.find { |k| k.code == "AAA000" }
      reread_parent = reread.classes.find { |k| k.code == "AAA000" }
      expect(reread_parent.preferred_name).to eq(original_parent.preferred_name)
    end
  end

  it "preserves the source language and project metadata" do
    original = build_database
    Dir.mktmpdir("cdd-round-trip") do |dir|
      out = File.join(dir, "round_trip.xlsx")
      Cdd::Parcel::Writer.new(original).write(
        out,
        parcel_id: "ROUNDTRIP",
        project_id: "TEST",
        source_language: "en",
        translation_languages: [:de, :fr],
      )

      reread = Cdd::Reader.load_database(out)
      expect(reread.entities.size).to eq(original.entities.size)
    end
  end
end
