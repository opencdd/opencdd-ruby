# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::GUID do
  describe ".generate" do
    it "returns a 36-character RFC 4122 v4 UUID" do
      uuid = described_class.generate
      expect(uuid.length).to eq(36)
      expect(described_class.valid?(uuid)).to be(true)
    end

    it "returns distinct values on repeated calls" do
      drawn = Array.new(20) { described_class.generate }
      expect(drawn.uniq.size).to eq(20)
    end
  end

  describe ".valid?" do
    it "accepts canonical 8-4-4-4-12 hex form (case-insensitive)" do
      expect(described_class.valid?("550e8400-e29b-41d4-a716-446655440000")).to be(true)
      expect(described_class.valid?("550E8400-E29B-41D4-A716-446655440000")).to be(true)
    end

    it "rejects malformed values" do
      expect(described_class.valid?("not-a-uuid")).to be(false)
      expect(described_class.valid?("550e8400-e29b-41d4-a716")).to be(false)
      expect(described_class.valid?("550e8400-e29b-41d4-a716-446655440000-extra")).to be(false)
      expect(described_class.valid?("ggge8400-e29b-41d4-a716-446655440000")).to be(false)
      expect(described_class.valid?("")).to be(false)
      expect(described_class.valid?(nil)).to be(false)
    end
  end

  describe ".set_on" do
    let(:entity) do
      Cdd::Property.new(
        irdi: Cdd::IRDI.parse("AAAP001"),
        properties: {},
        meta_class_irdi: Cdd::IRDI.parse("MDC_C003"),
      )
    end

    it "writes the GUID into MDC_P066 and returns it" do
      guid = described_class.set_on(entity)
      expect(guid).to eq(entity["MDC_P066"])
      expect(described_class.valid?(guid)).to be(true)
    end

    it "overwrites any prior value in MDC_P066" do
      entity.properties[Cdd::PropertyIds::MDC_P066] = "stale"
      described_class.set_on(entity)
      expect(entity["MDC_P066"]).not_to eq("stale")
    end
  end
end
