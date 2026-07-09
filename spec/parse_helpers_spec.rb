# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::ParseHelpers do
  describe ".parse_irdi_list" do
    it "returns [] for nil and blank input" do
      expect(described_class.parse_irdi_list(nil)).to eq([])
      expect(described_class.parse_irdi_list("")).to eq([])
      expect(described_class.parse_irdi_list("   ")).to eq([])
    end

    it "parses a single IRDI" do
      result = described_class.parse_irdi_list("0112/2///62683#ACE001")
      expect(result.map(&:to_s)).to eq(["0112/2///62683#ACE001"])
    end

    it "parses whitespace-separated IRDIs" do
      result = described_class.parse_irdi_list("0112/2///62683#ACE001 0112/2///62683#ACE002")
      expect(result.map(&:to_s)).to eq(["0112/2///62683#ACE001", "0112/2///62683#ACE002"])
    end

    it "parses comma-separated IRDIs" do
      result = described_class.parse_irdi_list("0112/2///62683#ACE001, 0112/2///62683#ACE002")
      expect(result.map(&:to_s)).to eq(["0112/2///62683#ACE001", "0112/2///62683#ACE002"])
    end

    it "strips surrounding parens" do
      result = described_class.parse_irdi_list("(0112/2///62683#ACE001)")
      expect(result.map(&:to_s)).to eq(["0112/2///62683#ACE001"])
    end

    it "filters out empty tokens" do
      result = described_class.parse_irdi_list("0112/2///62683#ACE001 , ")
      expect(result.map(&:to_s)).to eq(["0112/2///62683#ACE001"])
    end
  end

  describe ".parse_pair_list" do
    it "returns [] for nil and blank input" do
      expect(described_class.parse_pair_list(nil)).to eq([])
      expect(described_class.parse_pair_list("")).to eq([])
    end

    it "returns [[nil, s]] for a bare scalar that is not paren-wrapped" do
      expect(described_class.parse_pair_list("just a name")).to eq([[nil, "just a name"]])
    end

    it "splits paren-wrapped pairs into lang/name tuples" do
      result = described_class.parse_pair_list("(en, Hello, fr, Bonjour)")
      expect(result).to eq([["en", "Hello"], ["fr", "Bonjour"]])
    end

    it "strips whitespace inside pairs" do
      result = described_class.parse_pair_list("(en ,  Hello ,fr, Bonjour )")
      expect(result).to eq([["en", "Hello"], ["fr", "Bonjour"]])
    end
  end

  describe ".parse_string_list" do
    it "returns [] for nil and blank input" do
      expect(described_class.parse_string_list(nil)).to eq([])
      expect(described_class.parse_string_list("")).to eq([])
    end

    it "splits a comma-separated list" do
      expect(described_class.parse_string_list("a,b,c")).to eq(["a", "b", "c"])
    end

    it "strips each entry and rejects empties" do
      expect(described_class.parse_string_list(" a , ,b , ")).to eq(["a", "b"])
    end

    it "strips surrounding parens" do
      expect(described_class.parse_string_list("(a,b,c)")).to eq(["a", "b", "c"])
    end
  end

  describe ".unwrap_parens" do
    it "returns the string unchanged when not paren-wrapped" do
      expect(described_class.unwrap_parens("hello")).to eq("hello")
    end

    it "strips balanced outer parens" do
      expect(described_class.unwrap_parens("(hello)")).to eq("hello")
    end

    it "does not strip unbalanced parens" do
      expect(described_class.unwrap_parens("(hello")).to eq("(hello")
      expect(described_class.unwrap_parens("hello)")).to eq("hello)")
    end
  end

  describe "integration with Entity" do
    it "is mixed into Cdd::Entity so subclasses can use parse helpers as private methods" do
      expect(Cdd::Entity.ancestors).to include(Cdd::ParseHelpers)
      expect(Cdd::Klass.ancestors).to include(Cdd::ParseHelpers)
      expect(Cdd::Property.ancestors).to include(Cdd::ParseHelpers)
      expect(Cdd::Unit.ancestors).to include(Cdd::ParseHelpers)
      expect(Cdd::ValueList.ancestors).to include(Cdd::ParseHelpers)
      expect(Cdd::ValueTerm.ancestors).to include(Cdd::ParseHelpers)
      expect(Cdd::Relation.ancestors).to include(Cdd::ParseHelpers)
      expect(Cdd::ViewControl.ancestors).to include(Cdd::ParseHelpers)
    end

    it "exposes a working synonym accessor on Entity via the mixed-in parse_pair_list" do
      entity = Cdd::Entity.new(
        irdi: Cdd::IRDI.parse("0112/2///62683#ACC001"),
        properties: { "MDC_P007" => "(en, Foo, fr, Bidon)" },
      )
      expect(entity.synonymous_names).to eq([["en", "Foo"], ["fr", "Bidon"]])
    end

    it "exposes a working parse_irdi_list on Klass via the mixin" do
      schema = Cdd::Parcel::SheetSchema.from_header_rows([
        ["#PROPERTY_ID", "MDC_P001_5", "MDC_P013"],
        ["#PROPERTY_NAME.en", "Code", "Is case of"],
      ])
      klass = Cdd::Klass.from_row(
        { "MDC_P001_5" => "0112/2///62683#ACC001", "MDC_P013" => "0112/2///62683#ACC099" },
        schema: schema,
        meta_class_irdi: Cdd::IRDI.parse("0112/2///62656_1#MDC_C002"),
      )
      expect(klass.is_case_of_irdis.map(&:to_s)).to eq(["0112/2///62683#ACC099"])
    end
  end
end
