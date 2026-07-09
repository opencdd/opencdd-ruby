# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::Parcel::FlatDirReader do
  let(:reader) { described_class.new(LEGACY_XLS_DIR.to_s) }

  describe "#read_workbook" do
    subject(:workbook) { reader.read_workbook }

    it "collects one sheet per legacy file" do
      types = workbook.sheets.map(&:type).compact
      expect(types).to include(:class, :property, :unit, :value_list, :value_term)
    end

    it "synthesizes a sheetmap entry per file" do
      expect(workbook.sheetmap.size).to eq(workbook.sheets.size)
      types = workbook.sheetmap.map(&:type)
      expect(types).to include("CLASS", "PROPERTY", "UNIT", "VALUELIST", "VALUETERMS")
    end

    it "exposes the meta-class IRDI derived from the filename prefix" do
      klass = workbook.class_sheet
      expect(klass).not_to be_nil
      expect(klass.meta_class_irdi).to eq(Cdd::IRDI.parse("0112/2///62656_1#MDC_C002"))
    end
  end
end
