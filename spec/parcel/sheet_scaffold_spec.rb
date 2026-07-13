# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Parcel::Sheet, ".scaffold" do
  it "builds an empty sheet for MDC_C002 with the class allowed properties" do
    sheet = described_class.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
    expect(sheet.meta_class_code).to eq("MDC_C002")
    expect(sheet.name).to eq("OCDD1_CLASS")
    expect(sheet.schema.columns).not_to be_empty
    expect(sheet.schema.columns.map(&:property_id))
      .to include("MDC_P001_5", "MDC_P010", "MDC_P011", "MDC_P014")
  end

  it "writes CLASS_ID, CLASS_NAME, and SOURCE_LANGUAGE directives into metadata" do
    sheet = described_class.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
    expect(sheet.metadata["CLASS_ID"]).to eq("MDC_C002")
    expect(sheet.metadata["CLASS_NAME.en"]).to eq("Class")
    expect(sheet.metadata["SOURCE_LANGUAGE"]).to eq("en")
  end

  it "marks the code column as KEY" do
    sheet = described_class.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
    code_col = sheet.schema.find_by_property_id("MDC_P001_5")
    expect(code_col.requirement).to eq("KEY")
  end

  it "marks non-code columns as OPT" do
    sheet = described_class.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
    note_col = sheet.schema.find_by_property_id("MDC_P008")
    expect(note_col.requirement).to eq("OPT")
  end

  it "exposes translation languages when given" do
    sheet = described_class.scaffold(
      meta_class_irdi: "MDC_C003",
      parcel_id: "OCDD1",
      translation_languages: %w[fr ja],
    )
    expect(sheet.metadata["TRANSLATION_LANGUAGE"]).to eq("fr,ja")
    name_col = sheet.schema.find_by_property_id("MDC_P004")
    expect(name_col.name_by_lang.keys).to include("en", "fr", "ja")
  end

  it "scaffolds a Property sheet with the property allowed properties" do
    sheet = described_class.scaffold(meta_class_irdi: "MDC_C003", parcel_id: "OCDD1")
    expect(sheet.meta_class_code).to eq("MDC_C003")
    expect(sheet.schema.columns.map(&:property_id))
      .to include("MDC_P001_6", "MDC_P022", "MDC_P041")
  end

  it "scaffolds a Relation sheet with the relation allowed properties" do
    sheet = described_class.scaffold(meta_class_irdi: "MDC_C011", parcel_id: "OCDD1")
    expect(sheet.meta_class_code).to eq("MDC_C011")
    expect(sheet.schema.columns.map(&:property_id))
      .to include("MDC_P001_13", "MDC_P200", "MDC_P201")
  end

  it "raises for an unknown meta-class" do
    expect {
      described_class.scaffold(meta_class_irdi: "MDC_C999", parcel_id: "OCDD1")
    }.to raise_error(ArgumentError, /unknown meta-class/)
  end

  it "produces a sheet with zero data rows" do
    sheet = described_class.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
    expect(sheet.rows).to eq([])
    expect(sheet.raw_row_count).to eq(0)
  end

  it "honors an explicit sheet name" do
    sheet = described_class.scaffold(
      meta_class_irdi: "MDC_C002",
      parcel_id: "OCDD1",
      sheet_name: "CUSTOM_NAME",
    )
    expect(sheet.name).to eq("CUSTOM_NAME")
  end

  it "derives a default datatype from the property's value_kind" do
    sheet = described_class.scaffold(meta_class_irdi: "MDC_C002", parcel_id: "OCDD1")
    superclass_col = sheet.schema.find_by_property_id("MDC_P010")
    expect(superclass_col.datatype).to eq("ICID_STRING")
  end
end
