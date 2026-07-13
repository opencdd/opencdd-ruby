# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe Opencdd::ClassTree do
  let(:db) { Opencdd::Database.load(PARCEL_MAKER_XLSX.to_s) }
  subject(:tree) { described_class.new(db) }

  it "enumerates classes depth-first from roots" do
    codes = tree.map(&:code)
    expect(codes).to include("ACC001", "ACC010", "ACC100")
    expect(codes.index("ACC001")).to be < codes.index("ACC010")
  end

  it "yields (klass, depth) pairs from #each_node" do
    depths = {}
    tree.each_node { |k, d| depths[k.code] = d }
    expect(depths["ACC001"]).to eq(0)
    expect(depths["ACC010"]).to eq(1)
    acc011 = db.find_by_code("ACC011")
    expect(depths["ACC011"]).to be > depths["ACC010"] if acc011 && acc011.ancestors.any? { |a| a.code == "ACC010" }
  end

  describe "#to_h" do
    it "produces nested hash with code and name" do
      h = tree.to_h
      root = h.find { |n| n["code"] == "ACC001" }
      expect(root["name"]).to eq("LV switchgear and controlgear domain")
      expect(root["children"]).to be_an(Array)
      child_codes = root["children"].map { |c| c["code"] }
      expect(child_codes).to include("ACC010", "ACC100")
    end

    it "respects max_depth" do
      h = tree.to_h(max_depth: 1)
      root = h.find { |n| n["code"] == "ACC001" }
      expect(root["children"]).to be_an(Array)
      root["children"].each do |child|
        expect(child).not_to have_key("children")
      end
    end

    it "stops at max_depth: 0 (roots only)" do
      h = tree.to_h(max_depth: 0)
      h.each { |n| expect(n).not_to have_key("children") }
    end

    it "includes extra fields when requested" do
      h = tree.to_h(fields: %i[code name irdi definition])
      root = h.find { |n| n["code"] == "ACC001" }
      expect(root["irdi"]).to eq("0112/2///62683#ACC001")
      expect(root["definition"]).to match(/switching devices/i)
    end

    it "rejects unknown fields" do
      expect { tree.to_h(fields: %i[code bogus]) }
        .to raise_error(ArgumentError, /unknown field/)
    end
  end

  describe "#to_yaml" do
    it "emits valid YAML preserving structure" do
      yaml = tree.to_yaml(max_depth: 2)
      parsed = YAML.safe_load(yaml)
      root = parsed.find { |n| n["code"] == "ACC001" }
      expect(root["name"]).to eq("LV switchgear and controlgear domain")
      expect(root["children"]).to be_an(Array)
    end
  end

  describe "#subtree" do
    it "builds a single-rooted subtree from a given class" do
      acc010 = db.find_by_code("ACC010")
      h = tree.subtree(acc010)
      expect(h["code"]).to eq("ACC010")
      expect(h["children"]).to be_an(Array)
    end
  end

  describe "Opencdd::Database#class_tree" do
    it "returns a ClassTree bound to the database" do
      t = db.class_tree(fields: %i[code name irdi])
      yaml = t.to_yaml(max_depth: 1)
      parsed = YAML.safe_load(yaml)
      expect(parsed).to be_an(Array)
      expect(parsed.first["code"]).to be_a(String)
    end
  end
end
