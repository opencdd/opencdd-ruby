# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::Parcel::ScrapeVerifier do
  let(:verifier) { described_class.new(directory) }

  describe "#verify on a directory with populated .xls files" do
    let(:directory) { File.expand_path("../../downloads/iec-62683", __dir__) }

    it "returns ok results for CLASS files with data rows", :slow do
      skip "iec-62683 scrape not present locally" unless File.directory?(directory)
      results = verifier.verify
      class_results = results.select { |r| r.entity_type == "CLASS" }.first(20)
      skip "no CLASS .xls files in iec-62683" if class_results.empty?
      # CLASS files always have data rows; PROPERTY/VALUELIST/VALUETERMS
      # exports may be header-only for some classes (known scrape
      # characteristic — the iec61360 incident).
      expect(class_results).to all(satisfy(&:ok?))
    end
  end

  describe "#verify on the iec61360 family (regression)" do
    ["iec61360", "iec-63213", "iec-61360-7"].each do |dict|
      it "reports whether #{dict} property files have data", :slow do
        dir = File.expand_path("../../downloads/#{dict}", __dir__)
        skip "#{dict} scrape not present locally" unless File.directory?(dir)
        results = described_class.new(dir).verify
        property_results = results.select { |r| r.entity_type == "PROPERTY" }
        skip "no PROPERTY .xls files in #{dict}" if property_results.empty?
        # If any PROPERTY file is non-empty, the scrape captured data.
        # All-empty means the iec61360 incident recurred.
        empty_count = property_results.count(&:empty?)
        if empty_count == property_results.size
          warn "FAIL: all #{property_results.size} PROPERTY files in #{dict} are empty"
        end
        expect(empty_count).to be < property_results.size,
          "All #{property_results.size} PROPERTY files in #{dict} are empty — scrape captured headers only"
      end
    end
  end

  describe "#summary" do
    it "returns a hash with total/ok/empty/by_type counts" do
      dir = File.expand_path("../../downloads/iec-62683", __dir__)
      skip "iec-62683 scrape not present locally" unless File.directory?(dir)
      summary = described_class.new(dir).summary
      expect(summary).to include(:total, :ok, :empty, :by_type, :empty_by_type)
      expect(summary[:total]).to be_positive
    end
  end

  describe "#data_row?" do
    let(:verifier) { described_class.new(".") }

    it "treats hash-directive rows as non-data" do
      expect(verifier.data_row?(["#CLASS_ID:=MDC_C003"])).to be false
    end

    it "treats pure-comment rows as non-data" do
      expect(verifier.data_row?(["#", "x"])).to be false
    end

    it "treats rows with data past column 0 as data" do
      expect(verifier.data_row?(["", "AAA001", "voltage amplifier"])).to be true
    end

    it "rejects rows that are all blank past column 0" do
      expect(verifier.data_row?(["", "", ""])).to be false
    end
  end
end
