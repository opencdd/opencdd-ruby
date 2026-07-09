# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::Parcel::WorkbookReader do
  let(:reader) { described_class.new(PARCEL_MAKER_XLSX.to_s) }

  describe "#read_workbook" do
    subject(:workbook) { reader.read_workbook }

    it "exposes the project metadata" do
      expect(workbook.project.project_id).to eq("LOCAL")
      expect(workbook.project.parcel_id).to eq("IEC62683")
      expect(workbook.project.base_language).to eq("en")
    end

    it "exposes the sheetmap entries" do
      types = workbook.sheetmap.map(&:type)
      expect(types).to include("CLASS", "PROPERTY", "ENUM", "TERMINOLOGY", "UoM", "RELATION")
    end

    it "exposes one sheet per entity type" do
      expect(workbook.class_sheet.type).to eq(:class)
      expect(workbook.property_sheet.type).to eq(:property)
      expect(workbook.unit_sheet.type).to eq(:unit)
      expect(workbook.value_list_sheet.type).to eq(:value_list)
      expect(workbook.value_term_sheet.type).to eq(:value_term)
    end

    it "exposes the meta-class IRDI of each sheet" do
      expect(workbook.class_sheet.meta_class_irdi)
        .to eq(Cdd::IRDI.parse("0112/2///62656_1#MDC_C002"))
      expect(workbook.unit_sheet.meta_class_irdi)
        .to eq(Cdd::IRDI.parse("0112/2///62656_1#MDC_C009"))
    end
  end
end
