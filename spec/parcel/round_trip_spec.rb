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
    parent = Cdd::Klass.new(
      irdi: Cdd::IRDI.parse("0112/2///61360_4#AAA000"),
      properties: {
        "MDC_P001_5"  => "0112/2///61360_4#AAA000",
        "MDC_P011"    => "ITEM_CLASS",
        "MDC_P004.en" => "Component",
        "MDC_P005.en" => "CMP",
      },
      meta_class_irdi: Cdd::IRDI.parse("0112/2///62656_1#MDC_C001"),
    )
    klass = Cdd::Klass.new(
      irdi: Cdd::IRDI.parse("0112/2///61360_4#AAA001"),
      properties: {
        "MDC_P001_5"  => "0112/2///61360_4#AAA001",
        "MDC_P011"    => "ITEM_CLASS",
        "MDC_P004.en" => "Voltage amplifier",
        "MDC_P005.en" => "VTA",
        "MDC_P006.en" => "amplifier designed primarily to amplify voltage",
        "MDC_P010_1"  => "0112/2///61360_4#AAA000",
      },
      meta_class_irdi: Cdd::IRDI.parse("0112/2///62656_1#MDC_C001"),
    )
    db.add_entity(parent)
    db.add_entity(klass)
    db.finalize!
    db
  end

  # NOTE: These specs reveal that the Writer → Reader round-trip
  # currently loses entities (reread.entities is empty after a
  # write+read cycle). This is the kind of silent drift TODO.work/10
  # was meant to catch. Pending until the Writer/Reader pair is
  # aligned — tracked separately as a bug.
  it "round-trips classes through Parcel xlsx" do
    pending "Writer/Reader round-trip drift — reread loses entities; see TODO.work/10"

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

      # Spot-check both classes
      original_klass = original.classes.find { |k| k.code == "AAA001" }
      reread_klass = reread.classes.find { |k| k.code == "AAA001" }
      expect(reread_klass).not_to be_nil
      expect(reread_klass.preferred_name).to eq(original_klass.preferred_name)
      expect(reread_klass.short_name).to eq(original_klass.short_name)
      expect(reread_klass.definition).to eq(original_klass.definition)
      expect(reread_klass.class_type.to_s).to eq(original_klass.class_type.to_s)

      original_parent = original.classes.find { |k| k.code == "AAA000" }
      reread_parent = reread.classes.find { |k| k.code == "AAA000" }
      expect(reread_parent.preferred_name).to eq(original_parent.preferred_name)
    end
  end

  it "preserves the source language and project metadata" do
    pending "Writer/Reader round-trip drift — same root cause as above; see TODO.work/10"

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
