# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe Opencdd::Parcel::EntityManifest do
  let(:raw_json) do
    {
      "irdi"                => "0112/2///62656_1#AAA001",
      "entity_type"         => "class",
      "current_version_dir" => "ABCDEF0123456789ABCDEF0123456789",
      "versions"            => [
        {
          "version"           => 1,
          "revision"          => 0,
          "status"            => "Released",
          "timestamp"         => "2024-01-15T10:23:00Z",
          "user"              => "alice",
          "change_request_id" => "CR-001",
          "unid"              => "ABCDEF0123456789ABCDEF0123456789",
          "is_current"        => true,
        },
        {
          "version"    => 2,
          "revision"   => 1,
          "status"     => "Draft",
          "timestamp"  => "2024-02-20T09:00:00Z",
          "user"       => "bob",
          "unid"       => "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
          "is_current" => false,
        },
      ],
    }
  end

  subject(:manifest) { described_class.new(raw_json) }

  describe "#irdi" do
    it "parses the irdi field into an IRDI" do
      expect(manifest.irdi).to be_a(Opencdd::IRDI)
      expect(manifest.irdi.to_s).to eq("0112/2///62656_1#AAA001")
    end

    it "returns nil when irdi is missing" do
      expect(described_class.new({}).irdi).to be_nil
    end
  end

  describe "#entity_type" do
    it "returns the type as Symbol" do
      expect(manifest.entity_type).to eq(:class)
    end
  end

  describe "#meta_class_code" do
    it "resolves to MDC_C002 for :class type" do
      expect(manifest.meta_class_code).to eq("MDC_C002")
    end

    it "returns nil for unknown types" do
      expect(described_class.new("entity_type" => "made_up").meta_class_code).to be_nil
    end
  end

  describe "#current_version_dir" do
    it "returns the UNID of the current version" do
      expect(manifest.current_version_dir)
        .to eq("ABCDEF0123456789ABCDEF0123456789")
    end
  end

  describe "#version_history" do
    it "builds a VersionHistory with all entries" do
      vh = manifest.version_history
      expect(vh).to be_a(Opencdd::Entity::VersionHistory)
      expect(vh.entries.size).to eq(2)
      expect(vh.entries.first.version).to eq(1)
      expect(vh.entries.first.user).to eq("alice")
      expect(vh.entries.last.version).to eq(2)
    end

    it "returns empty history when versions is missing" do
      vh = described_class.new({}).version_history
      expect(vh.entries).to be_empty
    end
  end

  describe "#versions_empty?" do
    it "is false when versions exist" do
      expect(manifest.versions_empty?).to be(false)
    end

    it "is true when versions is empty" do
      expect(described_class.new({}).versions_empty?).to be(true)
    end
  end

  describe "#to_stub_entity" do
    it "builds a stub entity of the right subclass" do
      stub = manifest.to_stub_entity
      expect(stub).to be_a(Opencdd::Klass)
      expect(stub.irdi.to_s).to eq("0112/2///62656_1#AAA001")
      expect(stub.properties["MDC_P001_5"]).to eq("0112/2///62656_1#AAA001")
    end

    it "returns nil when irdi is missing" do
      expect(described_class.new("entity_type" => "class").to_stub_entity).to be_nil
    end

    it "returns nil when type is unknown" do
      m = described_class.new("irdi" => "AAA001", "entity_type" => "made_up")
      expect(m.to_stub_entity).to be_nil
    end

    it "builds a Property stub for property type" do
      m = described_class.new(
        "irdi"        => "0112/2///62656_1#AAAP001",
        "entity_type" => "property",
      )
      stub = m.to_stub_entity
      expect(stub).to be_a(Opencdd::Property)
      expect(stub.properties["MDC_P001_6"]).to eq("0112/2///62656_1#AAAP001")
    end
  end

  describe ".read" do
    it "returns a manifest when the file exists and parses" do
      Dir.mktmpdir("manifest-spec") do |dir|
        path = File.join(dir, "_entity.json")
        File.write(path, JSON.generate(raw_json))
        manifest = described_class.read(dir)
        expect(manifest).to be_a(described_class)
        expect(manifest.irdi.to_s).to eq("0112/2///62656_1#AAA001")
      end
    end

    it "returns nil when the file is missing" do
      Dir.mktmpdir("manifest-spec") do |dir|
        expect(described_class.read(dir)).to be_nil
      end
    end

    it "returns nil for unparseable JSON" do
      Dir.mktmpdir("manifest-spec") do |dir|
        path = File.join(dir, "_entity.json")
        File.write(path, "{ not json")
        expect(described_class.read(dir)).to be_nil
      end
    end
  end
end
