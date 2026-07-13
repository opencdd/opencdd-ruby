# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Parcel::Selector do
  let(:database) { Opencdd::Database.load_workbook(PARCEL_MAKER_XLSX.to_s) }

  describe "constructor" do
    it "defaults to entities=nil, closure=:none (select all)" do
      sel = described_class.new
      expect(sel.entities).to be_nil
      expect(sel.closure).to eq(:none)
    end

    it "rejects an unknown closure mode" do
      expect { described_class.new(closure: :everywhere) }
        .to raise_error(ArgumentError, /invalid closure/)
    end
  end

  describe "#resolve" do
    it "returns every entity when no seed and no closure" do
      sel = described_class.new
      resolved = sel.resolve(database)
      expect(resolved.size).to eq(database.entities.size)
    end

    it "returns only the seed entities when closure is :none" do
      target = database.classes.first
      sel = described_class.new(entities: [target.irdi.to_s], closure: :none)
      resolved = sel.resolve(database)
      expect(resolved).to include(target)
      expect(resolved.size).to be < database.entities.size
    end

    it "walks ancestors when closure is :ancestors" do
      deep_class = database.classes.find { |k| k.ancestors.size > 2 }
      skip "no nested class hierarchy in fixture" unless deep_class

      sel = described_class.new(entities: [deep_class.irdi.to_s], closure: :ancestors)
      resolved = sel.resolve(database)
      ancestor_codes = deep_class.ancestors.map(&:code)
      expect(resolved.map(&:code)).to include(*ancestor_codes)
    end

    it "walks descendants when closure is :descendants" do
      root = database.root_classes.first
      sel = described_class.new(entities: [root.irdi.to_s], closure: :descendants)
      resolved = sel.resolve(database)
      descendant_codes = root.descendants.map(&:code)
      expect(resolved.map(&:code)).to include(*descendant_codes) unless descendant_codes.empty?
    end

    it "lifts declared properties for selected classes" do
      root = database.root_classes.first
      sel = described_class.new(entities: [root.irdi.to_s], closure: :none)
      resolved = sel.resolve(database)
      root_props = database.properties_of(root)
      root_props.each do |prop|
        expect(resolved).to include(prop) if prop
      end
    end

    it "accepts Entity instances directly" do
      target = database.classes.first
      sel = described_class.new(entities: [target])
      expect(sel.resolve(database)).to include(target)
    end

    it "raises TypeError for unsupported entity reference types" do
      sel = described_class.new(entities: [42])
      expect { sel.resolve(database) }.to raise_error(TypeError, /must be Opencdd::Entity/)
    end
  end
end
