# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe Opencdd::Exporters::Json do
  let(:example_path) { REFERENCE_DOCS.join("examples/oceanrunner.cddal") }
  let(:database) { Opencdd::Cddal.parse_file(example_path) }
  let(:exporter) { described_class.new }

  describe "#payload_for" do
    context "with a class entity" do
      let(:entity) { database.classes.first }
      subject(:payload) { exporter.payload_for(entity, database: database) }

      it { is_expected.to include(type: "class") }
      it { is_expected.to include(irdi: entity.irdi.to_s) }
      it { is_expected.to include(code: entity.code) }

      it "includes preferred_name" do
        expect(payload["preferred_name"]).to eq(entity.preferred_name)
      end

      it "matches the slice emitted by to_json for the same entity" do
        full = JSON.parse(exporter.to_json(database))
        match = full.find { |n| n["irdi"] == entity.irdi.to_s }
        # The payload mixes symbol keys (:irdi, :code, :type) with
        # string keys (wire_name from field registry). Stringify all
        # keys for JSON parity.
        stringified = payload.transform_keys(&:to_s)
        expect(match).to eq(stringified)
      end
    end

    context "with a property entity" do
      let(:entity) { database.properties.find { |p| p.parsed_data_type } || database.properties.first }
      subject(:payload) { exporter.payload_for(entity, database: database) }

      it { is_expected.to include(type: "property") }
      it { is_expected.to include(irdi: entity.irdi.to_s) }

      it "includes the data_type when parsed" do
        skip "no property in fixture has a parsed data_type" unless entity.parsed_data_type
        expect(payload.key?(:data_type)).to be(true)
      end
    end

    context "with a value_list entity" do
      let(:entity) { database.value_lists.first }
      subject(:payload) { exporter.payload_for(entity, database: database) }

      it { is_expected.to include(type: "value_list") }
    end

    context "with a det_classification entity" do
      let(:entity) do
        Opencdd::DetClassification.new(
          irdi: Opencdd::IRDI.parse("0112/2///IECCDD_001#A11"),
          properties: {
            "MDC_P001_5" => "A11",
            "MDC_P004.en" => "geographical unit (greater than a place)",
          },
          meta_class_irdi: Opencdd::IRDI.parse("MDC_C0101"),
        )
      end
      subject(:payload) { exporter.payload_for(entity) }

      it { is_expected.to include(type: "det_classification") }
      it { is_expected.to include(irdi: "0112/2///IECCDD_001#A11") }
      it { is_expected.to include(code: "A11") }

      it "includes the preferred name" do
        expect(payload["preferred_name"]).to eq("geographical unit (greater than a place)")
      end
    end

    context "without a database (no cross-link resolution)" do
      let(:entity) { database.properties.first }
      subject(:payload) { exporter.payload_for(entity) }

      it "still emits all the entity's own fields" do
        expect(payload[:irdi]).to eq(entity.irdi.to_s)
        expect(payload[:type]).to eq("property")
      end
    end

    context "with an unsupported entity type" do
      let(:entity) { Struct.new(:foo).new("bar") }

      it "raises ArgumentError with a clear message" do
        expect { exporter.payload_for(entity) }.to raise_error(ArgumentError, /No JSON payload builder/)
      end
    end
  end

  describe "round-trip parity" do
    it "emits identical payloads whether via payload_for or to_json" do
      full = JSON.parse(exporter.to_json(database))
      classes_match = database.classes.all? do |klass|
        slice = exporter.payload_for(klass, database: database)
        match = full.find { |n| n["irdi"] == klass.irdi.to_s }
        match == slice.transform_keys(&:to_s)
      end
      expect(classes_match).to be(true)
    end
  end
end
