# frozen_string_literal: true

require "spec_helper"
require "set"

RSpec.describe Cdd::Parcel::Workbook, "header visibility" do
  def empty_workbook(hidden: nil)
    Cdd::Parcel::Workbook.new(sheets: [], sheetmap: [], hidden_header_rows: hidden)
  end

  describe "#hidden_header_rows" do
    it "defaults to an empty set" do
      wb = empty_workbook
      expect(wb.hidden_header_rows).to be_empty
      expect(wb.hidden_header_rows).to be_a(Set)
    end

    it "returns a defensive copy" do
      wb = empty_workbook
      snapshot = wb.hidden_header_rows
      wb.hide_header_row!(:pattern)
      expect(snapshot).to be_empty
      expect(wb.hidden_header_rows).to include(:pattern)
    end
  end

  describe "#hide_header_row!" do
    it "records a known header row as hidden" do
      wb = empty_workbook
      wb.hide_header_row!(:pattern)
      expect(wb.hidden_header_rows).to include(:pattern)
    end

    it "raises ArgumentError when hiding :class_id (mandatory)" do
      expect { empty_workbook.hide_header_row!(:class_id) }.to raise_error(ArgumentError, /class_id/)
    end

    it "raises ArgumentError when hiding :property_id (mandatory)" do
      expect { empty_workbook.hide_header_row!(:property_id) }.to raise_error(ArgumentError, /property_id/)
    end

    it "raises ArgumentError for unknown header rows" do
      expect { empty_workbook.hide_header_row!(:nope) }.to raise_error(ArgumentError, /unknown/)
    end

    it "accepts string names as well as symbols" do
      wb = empty_workbook
      wb.hide_header_row!("datatype")
      expect(wb.hidden_header_rows).to include(:datatype)
    end

    it "returns self for chaining" do
      wb = empty_workbook
      expect(wb.hide_header_row!(:pattern)).to be(wb)
    end
  end

  describe "#show_header_row!" do
    it "removes a row from the hidden set" do
      wb = empty_workbook(hidden: Set.new([:pattern, :unit]))
      wb.show_header_row!(:pattern)
      expect(wb.hidden_header_rows).not_to include(:pattern)
      expect(wb.hidden_header_rows).to include(:unit)
    end

    it "is a no-op when the row was not hidden" do
      wb = empty_workbook
      expect { wb.show_header_row!(:pattern) }.not_to raise_error
    end

    it "returns self for chaining" do
      wb = empty_workbook
      expect(wb.show_header_row!(:pattern)).to be(wb)
    end
  end

  describe "constructor validation" do
    it "rejects initial sets containing mandatory rows" do
      expect {
        empty_workbook(hidden: Set.new([:class_id]))
      }.to raise_error(ArgumentError, /mandatory/)
    end

    it "rejects initial sets containing unknown rows" do
      expect {
        empty_workbook(hidden: Set.new([:bogus]))
      }.to raise_error(ArgumentError, /unknown/)
    end

    it "accepts arrays as well as sets" do
      wb = empty_workbook(hidden: [:pattern, :unit])
      expect(wb.hidden_header_rows).to contain_exactly(:pattern, :unit)
    end
  end

  describe "HEADER_ROW_NAMES" do
    it "exposes the full list of recognized header row names" do
      names = Cdd::Parcel::Workbook::HEADER_ROW_NAMES
      expect(names).to include(:class_id, :property_id, :property_name,
                               :datatype, :value_format, :pattern,
                               :default_value, :requirement, :unit)
    end

    it "lists the mandatory rows separately" do
      mandatory = Cdd::Parcel::Workbook::MANDATORY_HEADER_ROWS
      expect(mandatory).to contain_exactly(:class_id, :property_id)
    end
  end
end
