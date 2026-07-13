# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

# Exercises the sharded per-class layout in downloads/iec63213/, which
# has 26 class subdirectories (KEA001..KEB124) each containing 4 .xls
# files (CLASS, PROPERTY, VALUELIST, VALUETERMS). The PROPERTY /
# VALUELIST / VALUETERMS workbooks currently hold header-only exports,
# so only the CLASS rows produce entities — that's a scrape-time data
# characteristic, not a reader bug.
RSpec.describe Opencdd::Parcel::ShardedDirReader do
  SHARDED_FIXTURE = File.expand_path("../../downloads/iec63213", __dir__)

  let(:reader) { described_class.new(SHARDED_FIXTURE) }

  before(:all) do
    skip "sharded fixture downloads/iec63213 not present" unless File.directory?(SHARDED_FIXTURE)
  end

  describe "#class_subdirs" do
    it "lists one subdir per class code" do
      subdirs = reader.class_subdirs
      expect(subdirs.size).to eq(26)
      expect(File.basename(subdirs.first)).to match(/\A[A-Z]{3}[0-9]{3}\z/)
    end
  end

  describe "#read_workbook" do
    subject(:workbook) { reader.read_workbook }

    it "synthesizes one sheet per (class, kind) pair" do
      types = workbook.sheets.map(&:type).compact
      expect(types).to include(:class, :property, :value_list, :value_term)
    end
  end

  describe "round-trip through Opencdd::Database" do
    subject(:database) do
      Opencdd::Database.new.tap { |db| reader.load_into(db); db.finalize! }
    end

    it "loads every class subdir as a distinct entity" do
      expect(database.classes.size).to eq(26)
    end

    it "is also reachable via Opencdd::Reader.detect → :sharded_dir" do
      expect(Opencdd::Reader.detect(SHARDED_FIXTURE)).to eq(:sharded_dir)
    end

    it "is also reachable via Opencdd::Database.load (auto-detect)" do
      db = Opencdd::Database.load(SHARDED_FIXTURE)
      expect(db.classes.size).to eq(database.classes.size)
    end
  end

  # Self-contained layout tests that don't depend on downloads/iec63213
  # state. Copies a real export_*.xls into the synthetic layout so the
  # reader exercises real XLS parsing, not just file existence checks.
  describe "per-version layout (nested <CODE>/<UNID>/export_*.xls)" do
    let(:fake_unid) { "1FF0BC2CBBBE16DBC125873E002DD576" }

    around do |ex|
      skip "sharded fixture downloads/iec63213 not present" unless File.directory?(SHARDED_FIXTURE)
      Dir.mktmpdir("cdd-per-version") do |tmp|
        @tmp = tmp
        code_dir = File.join(tmp, "KEA001")
        unid_dir = File.join(code_dir, fake_unid)
        FileUtils.mkdir_p(unid_dir)
        src_active = active_xls_source("KEA001")
        FileUtils.cp(Dir.glob("#{src_active}/export_*.xls"), unid_dir)
        File.write(File.join(code_dir, "_entity.json"),
                   JSON.dump("current_version_dir" => fake_unid,
                             "code" => "KEA001", "entity_type" => "class"))
        ex.run
      end
    end

    it "Opencdd::Reader.detect returns :sharded_dir" do
      expect(Opencdd::Reader.detect(@tmp)).to eq(:sharded_dir)
    end

    it "#active_xls_dir returns the nested UNID folder" do
      r = described_class.new(@tmp)
      active = r.active_xls_dir(File.join(@tmp, "KEA001"))
      expect(active).to eq(File.join(@tmp, "KEA001", fake_unid))
    end

    it "loads the workbook from the nested UNID folder" do
      r = described_class.new(@tmp)
      wb = r.read_workbook
      expect(wb.sheets.map(&:type).compact).to include(:class)
    end
  end

  describe "legacy flat layout (back-compat)" do
    around do |ex|
      skip "sharded fixture downloads/iec63213 not present" unless File.directory?(SHARDED_FIXTURE)
      Dir.mktmpdir("cdd-flat") do |tmp|
        @tmp = tmp
        code_dir = File.join(tmp, "KEA001")
        FileUtils.mkdir_p(code_dir)
        src_active = active_xls_source("KEA001")
        FileUtils.cp(Dir.glob("#{src_active}/export_*.xls"), code_dir)
        ex.run
      end
    end

    it "Opencdd::Reader.detect returns :sharded_dir" do
      expect(Opencdd::Reader.detect(@tmp)).to eq(:sharded_dir)
    end

    it "#active_xls_dir returns the code dir itself" do
      r = described_class.new(@tmp)
      active = r.active_xls_dir(File.join(@tmp, "KEA001"))
      expect(active).to eq(File.join(@tmp, "KEA001"))
    end
  end

  private

  # Returns the directory holding export_*.xls for a class — either the
  # per-version UNID subfolder (post-migration) or the class dir itself
  # (legacy flat layout).
  def active_xls_source(code)
    src = File.join(SHARDED_FIXTURE, code)
    nested = Dir.children(src)
      .select { |n| n =~ /\A[0-9A-F]{32}\z/i }
      .map { |n| File.join(src, n) }
      .find { |p| Dir.children(p).any? { |f| f =~ /\Aexport_.*\.xls\z/i } }
    nested || src
  end
end
