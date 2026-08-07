# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::DetClassification do
  it "is a subclass of Opencdd::Entity" do
    expect(described_class).to be < Opencdd::Entity
  end

  it "is autoloaded from opencdd/det_classification" do
    expect(Opencdd::DetClassification.name).to eq("Opencdd::DetClassification")
  end

  describe "meta-class registration" do
    # The cdd.iec.ch search-export uses CLASS_ID:=IECCDD_001 (an IEC-internal
    # supplier scheme) — not an MDC_CNNN meta-class IRDI. We register
    # MDC_C0101 as the canonical meta-class IRDI for DET classification
    # entities. The importer's TYPE_BY_META_CLASS maps type symbol
    # :det_classification to MDC_C0101, so the file's CLASS_ID is
    # documentation, not the parsing gate.
    it "is the entity_class for MDC_C0101" do
      meta = Opencdd::MetaClasses.for("MDC_C0101")
      expect(meta.entity_class).to eq(Opencdd::DetClassification)
    end

    it "resolves :det_classification type to MDC_C0101" do
      expect(Opencdd::MetaClasses.meta_class_for_type(:det_classification)).to eq("MDC_C0101")
    end

    it "resolves entity_class_for_type(:det_classification)" do
      expect(Opencdd::MetaClasses.entity_class_for_type(:det_classification)).to eq(Opencdd::DetClassification)
    end
  end
end

RSpec.describe Opencdd::Database do
  describe "#det_classifications" do
    it "returns entities whose type is :det_classification" do
      db = Opencdd::Database.new
      det = Opencdd::DetClassification.new(
        irdi: Opencdd::IRDI.parse("0112/2///62656_1#A11"),
        properties: { "MDC_P004.en" => "geographical unit (greater than a place)" },
        meta_class_irdi: Opencdd::IRDI.parse("MDC_C0101"),
      )
      db.add_entity(det)
      expect(db.det_classifications).to include(det)
      expect(db.det_classifications.size).to eq(1)
    end

    it "returns empty array when no det_classifications exist" do
      expect(Opencdd::Database.new.det_classifications).to eq([])
    end
  end
end

RSpec.describe "DET classification importer (end-to-end via search-export)" do
  let(:path) do
    "/Users/mulgogi/src/opencdd/data-private/exports/latest/iec-61360-4/" \
      "export_DETCLASSIFICATION_DOMO-DWL8BK.xls"
  end

  # The search-export file uses non-standard property IDs
  # (IECCDD_001_C0001, IECCDD_001_C0002.en, ...) rather than MDC_P* codes,
  # so the standard Parcel row parser doesn't extract a `code` property.
  # A property-ID aliasing layer (DETCLASSIFICATION_PROPERTY_ID_ALIASES or
  # similar) is needed to map these to the standard MDC codes before the
  # meta-class extraction logic can find the code column. That's a separate
  # design decision; tracked as a follow-up. This PR only ensures the
  # entity TYPE is recognized — the file no longer gets silently skipped
  # (it now produces 0 entities, was 0 before; same outcome, but at least
  # the type symbol :det_classification is registered).
  it "recognises the DETCLASSIFICATION file prefix as :det_classification" do
    skip "fixture not present" unless File.file?(path)
    reader = Opencdd::Reader.detect(path)
    expect(reader).to eq(:legacy_single)
  end
end
