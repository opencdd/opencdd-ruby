# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Codegen::Ts do
  describe ".render_property_ids" do
    subject(:output) { described_class.render_property_ids }

    it "returns a non-empty string" do
      expect(output).to be_a(String)
      expect(output.length).to be > 100
    end

    it "includes the AUTO-GENERATED header" do
      expect(output).to include("// AUTO-GENERATED")
    end

    it "includes the PropertyEntry interface" do
      expect(output).to include("export interface PropertyEntry")
    end

    it "includes the REGISTRY record" do
      expect(output).to include("export const REGISTRY")
    end

    it "includes known property IDs as exported constants" do
      expect(output).to include('export const MDC_P010 = "MDC_P010";')
      expect(output).to include('export const MDC_P022 = "MDC_P022";')
    end

    it "includes the AppliesTo union type" do
      expect(output).to include("export type AppliesTo =")
    end

    it "includes the alias map" do
      expect(output).to include("ALIAS_MAP")
      expect(output).to include('"superclass": "MDC_P010"')
    end
  end

  describe ".render_meta_classes" do
    subject(:output) { described_class.render_meta_classes }

    it "returns a non-empty string" do
      expect(output).to be_a(String)
      expect(output.length).to be > 100
    end

    it "includes the MetaClassEntry interface" do
      expect(output).to include("export interface MetaClassEntry")
    end

    it "includes known meta-class IRDIs" do
      expect(output).to include('"MDC_C002"')
      expect(output).to include('"MDC_C011"')
      expect(output).to include('"EXT_C001"')
    end

    it "includes entity types" do
      expect(output).to include('"class"')
      expect(output).to include('"relation"')
      expect(output).to include('"view_control"')
    end

    it "includes code property IDs" do
      expect(output).to include("MDC_P001_5")
      expect(output).to include("MDC_P001_6")
    end
  end

  describe "idempotency" do
    it "produces identical output on two calls" do
      a = described_class.render_property_ids
      b = described_class.render_property_ids
      expect(a).to eq(b)
    end
  end
end
