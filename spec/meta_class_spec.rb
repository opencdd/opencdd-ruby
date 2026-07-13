# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::MetaClass do
  describe "constructor" do
    it "freezes the allowed_property_ids list" do
      mc = described_class.new(irdi: "EXT_C900", name: "Demo", allowed_property_ids: %w[MDC_P004])
      expect(mc.allowed_property_ids).to be_frozen
      expect(mc.allowed_property_ids).to eq(%w[MDC_P004])
    end

    it "coerces irdi and name to strings" do
      mc = described_class.new(irdi: :EXT_C900, name: :Demo)
      expect(mc.irdi).to eq("EXT_C900")
      expect(mc.name).to eq("Demo")
    end
  end

  describe "#allows_property?" do
    it "returns true for declared ids" do
      mc = described_class.new(irdi: "EXT_C900", name: "Demo", allowed_property_ids: %w[MDC_P004])
      expect(mc.allows_property?("MDC_P004")).to be(true)
      expect(mc.allows_property?("MDC_P005")).to be(false)
    end
  end

  describe "#merge" do
    it "unions allowed_property_ids" do
      a = described_class.new(irdi: "EXT_C900", name: "Demo", allowed_property_ids: %w[MDC_P004])
      b = described_class.new(irdi: "EXT_C900", name: "Demo", allowed_property_ids: %w[MDC_P005])
      merged = a.merge(b)
      expect(merged.allowed_property_ids).to contain_exactly("MDC_P004", "MDC_P005")
    end

    it "preserves existing entity_class when other has none" do
      a = described_class.new(irdi: "EXT_C900", name: "Demo", entity_class: Opencdd::Klass, allowed_property_ids: %w[MDC_P004])
      b = described_class.new(irdi: "EXT_C900", name: "Demo", allowed_property_ids: %w[MDC_P005])
      expect(a.merge(b).entity_class).to equal(Opencdd::Klass)
    end

    it "raises when IRDI mismatch" do
      a = described_class.new(irdi: "EXT_C900", name: "Demo")
      b = described_class.new(irdi: "EXT_C901", name: "Other")
      expect { a.merge(b) }.to raise_error(ArgumentError, /IRDI mismatch/)
    end
  end

  describe "Opencdd::MetaClasses registry" do
    after { Opencdd::MetaClasses.reset! }

    describe ".for" do
      it "returns the Class meta-class for MDC_C002" do
        mc = Opencdd::MetaClasses.for("MDC_C002")
        expect(mc).to be_a(described_class)
        expect(mc.name).to eq("Class")
        expect(mc.entity_class).to equal(Opencdd::Klass)
        expect(mc.allows_property?("MDC_P010")).to be(true)
      end

      it "returns the Property meta-class for MDC_C003" do
        mc = Opencdd::MetaClasses.for("MDC_C003")
        expect(mc.name).to eq("Property")
        expect(mc.entity_class).to equal(Opencdd::Property)
      end

      it "returns the ViewControl meta-class for EXT_C001" do
        mc = Opencdd::MetaClasses.for("EXT_C001")
        expect(mc.entity_class).to equal(Opencdd::ViewControl)
      end

      it "returns nil for unknown IRDI" do
        expect(Opencdd::MetaClasses.for("MDC_C999")).to be_nil
      end
    end

    describe ".register" do
      it "registers a new meta-class" do
        custom = described_class.new(
          irdi: "EXT_C900",
          name: "Custom",
          entity_class: Opencdd::Klass,
          allowed_property_ids: %w[MDC_P004],
        )
        Opencdd::MetaClasses.register(custom)
        expect(Opencdd::MetaClasses.for("EXT_C900")).to equal(custom)
      end

      it "merges with an existing registration" do
        first = described_class.new(irdi: "EXT_C900", name: "Custom", allowed_property_ids: %w[MDC_P004])
        second = described_class.new(irdi: "EXT_C900", name: "Custom", allowed_property_ids: %w[MDC_P005])
        Opencdd::MetaClasses.register(first)
        merged = Opencdd::MetaClasses.register(second)
        expect(merged.allowed_property_ids).to contain_exactly("MDC_P004", "MDC_P005")
      end
    end

    describe ".all and .codes" do
      it "returns all registered meta-classes" do
        all = Opencdd::MetaClasses.all
        codes = Opencdd::MetaClasses.codes
        expect(all.map(&:irdi)).to eq(codes)
        expect(codes).to include("MDC_C002", "MDC_C003", "MDC_C005", "MDC_C009", "MDC_C010", "MDC_C011", "EXT_C001")
      end
    end

    describe ".reset!" do
      it "restores the built-in registry" do
        custom = described_class.new(irdi: "EXT_C900", name: "Custom", allowed_property_ids: %w[MDC_P004])
        Opencdd::MetaClasses.register(custom)
        expect(Opencdd::MetaClasses.for("EXT_C900")).not_to be_nil
        Opencdd::MetaClasses.reset!
        expect(Opencdd::MetaClasses.for("EXT_C900")).to be_nil
        expect(Opencdd::MetaClasses.for("MDC_C002")).not_to be_nil
      end
    end
  end
end
