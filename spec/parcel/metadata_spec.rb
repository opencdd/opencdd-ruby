# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::Parcel::Metadata do
  describe ".new + #add" do
    it "parses a #KEY:=VALUE directive into the directives hash" do
      m = described_class.new
      m.add("#CLASS_ID:=MDC_C002")
      expect(m["CLASS_ID"]).to eq("MDC_C002")
    end

    it "ignores non-directive cells" do
      m = described_class.new
      m.add("hello world")
      m.add("")
      expect(m.directives).to be_empty
    end

    it "exposes the meta-class IRDI" do
      m = described_class.new
      m.add("#CLASS_ID:=MDC_C002")
      expect(m.meta_class_irdi).to eq(Cdd::IRDI.parse("MDC_C002"))
      expect(m.meta_class_code).to eq("MDC_C002")
    end

    it "exposes the entity type derived from the meta-class code" do
      m = described_class.new
      m.add("#CLASS_ID:=MDC_C002")
      expect(m.type).to eq(:class)
    end

    it "returns nil type when the meta-class code is unknown" do
      m = described_class.new
      m.add("#CLASS_ID:=FOO_BAR")
      expect(m.type).to be_nil
    end
  end

  describe "language-specific accessors" do
    let(:m) do
      described_class.new.tap do |x|
        x.add("#CLASS_NAME.en:=Class meta-class")
        x.add("#CLASS_DEFINITION.en:=meta-class being characterized")
        x.add("#CLASS_NOTE.en:=Always needed for dictionary exchange.")
        x.add("#SOURCE_LANGUAGE:=en")
        x.add("#DEFAULT_SUPPLIER:=0112/2///62656_1")
      end
    end

    it "exposes class_name, class_definition, class_note" do
      expect(m.class_name).to eq("Class meta-class")
      expect(m.class_definition).to eq("meta-class being characterized")
      expect(m.class_note).to eq("Always needed for dictionary exchange.")
    end

    it "exposes source_language and default_supplier" do
      expect(m.source_language).to eq("en")
      expect(m.default_supplier).to eq("0112/2///62656_1")
    end
  end
end
