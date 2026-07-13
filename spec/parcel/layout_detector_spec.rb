# frozen_string_literal: true

require "spec_helper"
require "json"
require "tmpdir"

RSpec.describe Opencdd::Parcel::LayoutDetector do
  let(:workdir) { Dir.mktmpdir("layout-detector-spec") }

  after { FileUtils.remove_entry(workdir) if Dir.exist?(workdir) }

  describe "CLASS_CODE_PATTERN" do
    it "matches class codes" do
      expect(described_class.class_code?("AAA001")).to be(true)
      expect(described_class.class_code?("UAC696")).to be(true)
      expect(described_class.class_code?("AAA001-FIXED")).to be(true)
    end

    it "rejects non-class names" do
      expect(described_class.class_code?("aaa001")).to be(false)
      expect(described_class.class_code?("A1")).to be(false)
      expect(described_class.class_code?("_entity.json")).to be(false)
      expect(described_class.class_code?("123ABC")).to be(false)
    end
  end

  describe "FILE_PATTERN / legacy_export?" do
    it "matches export filenames" do
      expect(described_class.legacy_export?("export_CLASS_TSTM-BKSGSW.xls")).to be(true)
      expect(described_class.legacy_export?("export_PROPERTY_ABC.xlsx")).to be(true)
    end

    it "rejects non-export names" do
      expect(described_class.legacy_export?("_entity.json")).to be(false)
      expect(described_class.legacy_export?("readme.txt")).to be(false)
    end
  end

  describe "UNID_PATTERN / unid?" do
    it "matches UNID hex strings" do
      expect(described_class.unid?("ABCDEF0123456789ABCDEF0123456789")).to be(true)
    end

    it "rejects short strings" do
      expect(described_class.unid?("ABC123")).to be(false)
    end
  end

  describe "active_xls_dir" do
    it "returns the code dir itself for flat layout" do
      code_dir = File.join(workdir, "AAA001")
      Dir.mkdir(code_dir)
      FileUtils.touch(File.join(code_dir, "export_CLASS_AAA001.xls"))
      expect(described_class.active_xls_dir(code_dir)).to eq(code_dir)
    end

    it "returns nil when no XLS present" do
      code_dir = File.join(workdir, "AAA002")
      Dir.mkdir(code_dir)
      expect(described_class.active_xls_dir(code_dir)).to be_nil
    end

    it "uses _entity.json to find the current version dir" do
      code_dir = File.join(workdir, "AAA003")
      Dir.mkdir(code_dir)
      unid = "ABCDEF0123456789ABCDEF0123456789"
      version_dir = File.join(code_dir, unid)
      Dir.mkdir(version_dir)
      FileUtils.touch(File.join(version_dir, "export_CLASS_AAA003.xls"))
      File.write(File.join(code_dir, "_entity.json"),
                 JSON.generate("current_version_dir" => unid))
      expect(described_class.active_xls_dir(code_dir)).to eq(version_dir)
    end

    it "falls back to unique UNID subfolder when no manifest" do
      code_dir = File.join(workdir, "AAA004")
      Dir.mkdir(code_dir)
      unid = "ABCDEF0123456789ABCDEF0123456789"
      version_dir = File.join(code_dir, unid)
      Dir.mkdir(version_dir)
      FileUtils.touch(File.join(version_dir, "export_CLASS_AAA004.xls"))
      expect(described_class.active_xls_dir(code_dir)).to eq(version_dir)
    end
  end

  describe "sharded_class_subdir?" do
    it "is true for class-code dirs with XLS" do
      code_dir = File.join(workdir, "AAA001")
      Dir.mkdir(code_dir)
      FileUtils.touch(File.join(code_dir, "export_CLASS_AAA001.xls"))
      expect(described_class.sharded_class_subdir?(code_dir)).to be(true)
    end

    it "is false for non-class-code dirs" do
      other = File.join(workdir, "misc")
      Dir.mkdir(other)
      expect(described_class.sharded_class_subdir?(other)).to be(false)
    end

    it "is false for class-code dirs without XLS" do
      code_dir = File.join(workdir, "AAA099")
      Dir.mkdir(code_dir)
      expect(described_class.sharded_class_subdir?(code_dir)).to be(false)
    end
  end
end
