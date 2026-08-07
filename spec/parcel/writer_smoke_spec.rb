# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

# End-to-end smoke test for the build-time Parcel emit pipeline.
# Exercises the same path used by `rake browser:build_parcel[<dict>]`:
# load_database → Parcel::Writer#write → Parcel::WorkbookReader round-trip.
RSpec.describe "Parcel build-pipeline smoke" do
  SOURCE_DIR = File.expand_path("../../downloads/iec-63213", __dir__)

  before(:all) do
    skip "downloads/iec-63213 fixture not present" unless File.directory?(SOURCE_DIR)
  end

  let(:database) { Opencdd::Reader.load_database(SOURCE_DIR) }

  it "loads iec-63213, emits a Parcel xlsx, and reloads equivalent entities" do
    dir = Dir.mktmpdir("parcel-smoke")
    out_path = File.join(dir, "IEC63213.xlsx")
    begin
      Opencdd::Parcel::Writer.new(database).write(out_path, parcel_id: "IEC63213")
      expect(File.file?(out_path)).to be(true)
      expect(File.size(out_path)).to be > 0

      reloaded = Opencdd::Database.load_workbook(out_path)
      expect(reloaded.classes.size).to eq(database.classes.size)
      expect(reloaded.properties.size).to eq(database.properties.size)
      # The first class should round-trip with the same code and preferred name.
      original_first = database.classes.min_by { |k| k.code.to_s }
      round_first = reloaded.find(original_first.irdi)
      expect(round_first).not_to be_nil
      expect(round_first.code).to eq(original_first.code)
    ensure
      FileUtils.rm_rf(dir)
    end
  end
end
