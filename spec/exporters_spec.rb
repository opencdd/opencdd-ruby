# frozen_string_literal: true

require "spec_helper"
require "json"
require "yaml"

RSpec.describe Opencdd::Exporters do
  let(:database) { Opencdd::Cddal.parse_file(REFERENCE_DOCS.join("examples/oceanrunner.cddal")) }

  describe Opencdd::Exporters::Json do
    it "produces parseable JSON with class, property, and value_list nodes" do
      text = described_class.new.to_json(database)
      parsed = JSON.parse(text)
      types = parsed.map { |n| n.fetch("type") }
      expect(types.tally).to include(
        "class"       => database.classes.size,
        "property"    => database.properties.size,
        "value_list"  => database.value_lists.size,
      )
    end

    it "emits class_type and is_case_of for categorical classes" do
      text = described_class.new.to_json(database)
      parsed = JSON.parse(text)
      engine_type = parsed.find { |n| n["code"] == "AAA200" }
      expect(engine_type["class_type"]).to eq("CATEGORICAL_CLASS")
    end

    it "emits value_list on properties whose data type references a value list" do
      text = described_class.new.to_json(database)
      parsed = JSON.parse(text)
      operating_mode = parsed.find { |n| n["code"] == "AAAP100" }
      expect(operating_mode["data_type"]).to eq("ENUM_STRING_TYPE(vehicle_mode_enum)")
      expect(operating_mode["value_list"]).to eq("AAAE001")
    end

    it "omits value_list on properties without an enumerated data type" do
      text = described_class.new.to_json(database)
      parsed = JSON.parse(text)
      non_enum = parsed.find { |n| n["code"] == "AAAP001" }
      expect(non_enum["data_type"]).to eq("REAL_TYPE")
      expect(non_enum).not_to have_key("value_list")
    end

    it "compacts nil values out of each node" do
      text = described_class.new.to_json(database)
      parsed = JSON.parse(text)
      parsed.each do |node|
        expect(node.values).not_to include(nil), "node #{node["code"]} has nil values"
      end
    end

    it "supports compact (single-line) output" do
      compact = described_class.new.to_json(database, pretty: false)
      expect(compact.lines.size).to eq(1)
    end

    it "emits the shared cdd.iec.ch-style metadata on every node" do
      text = described_class.new.to_json(database)
      parsed = JSON.parse(text)
      parsed.each do |node|
        expect(node).to include("synonyms")
        expect(node["synonyms"]).to be_an(Array)
        expect(node["guid"]).to satisfy { |v| v.nil? || v.is_a?(String) }
        expect(node["version"]).to satisfy { |v| v.nil? || v.is_a?(String) }
        expect(node["revision"]).to satisfy { |v| v.nil? || v.is_a?(String) }
        expect(node["source_document"]).to satisfy { |v| v.nil? || v.is_a?(String) }
        expect(node["time_stamp"]).to satisfy { |v| v.nil? || v.is_a?(String) }
      end
    end

    it "emits the dates hash only when at least one date is present" do
      text = described_class.new.to_json(database)
      parsed = JSON.parse(text)
      parsed.each do |node|
        dates = node["dates"]
        next unless dates
        expect(dates).to be_a(Hash)
        expect(dates).not_to be_empty
        # Every key in the dates hash must be one of the three known fields.
        expect(dates.keys).to all(satisfify { |k| %w[original_definition current_version current_revision].include?(k) })
      end
    end

    it "emits the dates hash when an entity carries MDC_P003_* values" do
      meta = Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002")
      klass = Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse("0112/2///62656_4#AAA001"),
        properties: {
          Opencdd::PropertyIds::MDC_P001_5 => "0112/2///62656_4#AAA001",
          Opencdd::PropertyIds::MDC_P003_1 => "2024-01-01",
          Opencdd::PropertyIds::MDC_P003_2 => "2024-06-01",
          Opencdd::PropertyIds::MDC_P066   => "guid-abc-123",
          Opencdd::PropertyIds::MDC_P067   => "2024-06-01T00:00:00Z",
          Opencdd::PropertyIds::MDC_P002_1 => "001",
          Opencdd::PropertyIds::MDC_P002_2 => "02",
        },
        meta_class_irdi: meta,
      )
      db = Opencdd::Database.new.add_entity(klass)
      node = JSON.parse(described_class.new.to_json(db)).first
      expect(node["dates"]).to eq(
        "original_definition" => "2024-01-01",
        "current_version"     => "2024-06-01",
      )
      expect(node["guid"]).to eq("guid-abc-123")
      expect(node["time_stamp"]).to eq("2024-06-01T00:00:00Z")
      expect(node["version"]).to eq("001")
      expect(node["revision"]).to eq("02")
    end

    it "omits the dates hash when no MDC_P003_* values are set" do
      meta = Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002")
      klass = Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse("0112/2///62656_4#AAA002"),
        properties: {
          Opencdd::PropertyIds::MDC_P001_5 => "0112/2///62656_4#AAA002",
        },
        meta_class_irdi: meta,
      )
      db = Opencdd::Database.new.add_entity(klass)
      node = JSON.parse(described_class.new.to_json(db)).first
      expect(node).not_to have_key("dates")
    end

    it "serializes synonyms as {lang, name} pairs" do
      text = described_class.new.to_json(database)
      parsed = JSON.parse(text)
      all_synonyms = parsed.flat_map { |n| n["synonyms"] }
      all_synonyms.each do |syn|
        expect(syn).to be_a(Hash)
        expect(syn.keys).to match_array(%w[lang name])
      end
    end

    it "emits sub_class_selection when the class declares composition children" do
      meta = Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002")
      parent_irdi = Opencdd::IRDI.parse("0112/2///62656_4#COMPOSED")
      child_irdi = Opencdd::IRDI.parse("0112/2///62656_4#COMPOSED_PART")
      klass = Opencdd::Klass.new(
        irdi: parent_irdi,
        properties: {
          Opencdd::PropertyIds::MDC_P001_5           => parent_irdi.to_s,
          Opencdd::PropertyIds::MDC_P016             => child_irdi.to_s,
        },
        meta_class_irdi: meta,
      )
      db = Opencdd::Database.new.add_entity(klass)
      node = JSON.parse(described_class.new.to_json(db)).first
      expect(node["sub_class_selection"]).to eq([child_irdi.to_s])
    end

    it "emits sub_class_selection as an empty array when the class has no composition children" do
      meta = Opencdd::IRDI.parse("0112/2///62656_1#MDC_C002")
      klass = Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse("0112/2///62656_4#LEAF"),
        properties: {
          Opencdd::PropertyIds::MDC_P001_5 => "0112/2///62656_4#LEAF",
        },
        meta_class_irdi: meta,
      )
      db = Opencdd::Database.new.add_entity(klass)
      node = JSON.parse(described_class.new.to_json(db)).first
      expect(node["sub_class_selection"]).to eq([])
    end
  end

  describe Opencdd::Exporters::Yaml do
    it "produces parseable YAML mirroring the JSON shape" do
      text = described_class.new.to_yaml(database)
      parsed = YAML.safe_load(text, permitted_classes: [Symbol], aliases: true)
      types = parsed.map { |n| n.fetch(:type) }
      expect(types.tally).to include(
        "class"       => database.classes.size,
        "property"    => database.properties.size,
        "value_list"  => database.value_lists.size,
      )
    end
  end

  describe Opencdd::Exporters::Mermaid do
    it "emits a classDiagram directive" do
      diagram = described_class.new.to_diagram(database)
      expect(diagram.lines.first.strip).to eq("classDiagram")
    end

    it "emits inheritance edges for the superclass hierarchy" do
      diagram = described_class.new.to_diagram(database)
      expect(diagram).to include("AAA001 <|-- AAA010")
      expect(diagram).to include("AAA001 <|-- AAA020")
      expect(diagram).to include("AAA001 <|-- AAA030")
    end

    it "emits is_case_of edges for powertype composition" do
      diagram = described_class.new.to_diagram(database)
      expect(diagram).to include("<.. AAA100 : is_case_of")
    end

    it "includes class_type annotation for categorical classes" do
      diagram = described_class.new.to_diagram(database)
      expect(diagram).to match(/class AAA200 \{\s*<<CATEGORICAL_CLASS>>/)
    end
  end
end
