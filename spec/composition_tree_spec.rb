# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::CompositionTree do
  let(:oceanrunner_db) { Opencdd::Cddal.parse_file(REFERENCE_DOCS.join("examples/oceanrunner.cddal")) }

  describe Opencdd::CompositionTree::Node do
    it "is a Struct exposing entity and children" do
      node = described_class.new(entity: "x", children: [])
      expect(node.entity).to eq("x")
      expect(node.children).to eq([])
    end

    it "is Enumerable and walks depth-first" do
      leaf1 = described_class.new(entity: :leaf1, children: [])
      leaf2 = described_class.new(entity: :leaf2, children: [])
      root  = described_class.new(entity: :root, children: [leaf1, leaf2])
      expect(root.map(&:entity)).to eq(%i[root leaf1 leaf2])
    end

    it "reports size and depth" do
      deep = described_class.new(entity: :deep, children: [])
      mid  = described_class.new(entity: :mid, children: [deep])
      root = described_class.new(entity: :root, children: [mid])
      expect(root.size).to eq(3)
      expect(root.depth).to eq(3)
    end

    it "knows when it is a leaf" do
      expect(described_class.new(entity: :x, children: []).leaf?).to be(true)
      expect(described_class.new(entity: :x, children: [:c]).leaf?).to be(false)
    end
  end

  describe "#for with a single class of scalar properties" do
    let(:db) do
      Opencdd::Database.new.tap do |d|
        klass = Opencdd::Klass.new(
          irdi: Opencdd::IRDI.parse("AAA001"),
          properties: {
            "MDC_P001_5" => "AAA001",
            "MDC_P011"   => "ITEM_CLASS",
            "MDC_P014"   => "(AAAP001,AAAP002,AAAP003)",
          },
          meta_class_irdi: Opencdd::IRDI.parse("MDC_C002"),
        )
        %w[AAAP001 AAAP002 AAAP003].each_with_index do |code, i|
          d.add_entity(Opencdd::Property.new(
            irdi: Opencdd::IRDI.parse(code),
            properties: { "MDC_P001_6" => code, "MDC_P022" => "STRING_TYPE" },
            meta_class_irdi: Opencdd::IRDI.parse("MDC_C003"),
          ))
          i
        end
        d.add_entity(klass)
        d.finalize!
      end
    end

    it "emits root class with three property leaves" do
      tree = described_class.new(db).for(db.find_by_code("AAA001"))
      expect(tree.entity).to be_a(Opencdd::Klass)
      expect(tree.entity.code).to eq("AAA001")
      expect(tree.children.size).to eq(3)
      expect(tree.children.map { |c| c.entity.code }).to contain_exactly("AAAP001", "AAAP002", "AAAP003")
      expect(tree.children.all?(&:leaf?)).to be(true)
    end

    it "exposes only Klass entities via #classes and only Property via #properties" do
      tree = described_class.new(db).for(db.find_by_code("AAA001"))
      expect(tree.classes.map(&:code)).to eq(%w[AAA001])
      expect(tree.properties.map(&:code)).to contain_exactly("AAAP001", "AAAP002", "AAAP003")
    end
  end

  describe "#for with CLASS_REFERENCE recursion" do
    let(:db) do
      Opencdd::Database.new.tap do |d|
        target = Opencdd::Klass.new(
          irdi: Opencdd::IRDI.parse("AAA010"),
          properties: {
            "MDC_P001_5" => "AAA010",
            "MDC_P011"   => "ITEM_CLASS",
            "MDC_P014"   => "(AAAP101)",
          },
          meta_class_irdi: Opencdd::IRDI.parse("MDC_C002"),
        )
        target_prop = Opencdd::Property.new(
          irdi: Opencdd::IRDI.parse("AAAP101"),
          properties: { "MDC_P001_6" => "AAAP101", "MDC_P022" => "STRING_TYPE" },
          meta_class_irdi: Opencdd::IRDI.parse("MDC_C003"),
        )
        owner = Opencdd::Klass.new(
          irdi: Opencdd::IRDI.parse("AAA001"),
          properties: {
            "MDC_P001_5" => "AAA001",
            "MDC_P011"   => "ITEM_CLASS",
            "MDC_P014"   => "(AAAP001)",
          },
          meta_class_irdi: Opencdd::IRDI.parse("MDC_C002"),
        )
        ref_prop = Opencdd::Property.new(
          irdi: Opencdd::IRDI.parse("AAAP001"),
          properties: {
            "MDC_P001_6" => "AAAP001",
            "MDC_P022"   => "CLASS_REFERENCE(AAA010)",
          },
          meta_class_irdi: Opencdd::IRDI.parse("MDC_C003"),
        )
        d.add_entity(target)
        d.add_entity(target_prop)
        d.add_entity(owner)
        d.add_entity(ref_prop)
        d.finalize!
      end
    end

    it "recurses into the referenced class and emits its properties" do
      tree = described_class.new(db).for(db.find_by_code("AAA001"))
      ref_node = tree.children.find { |c| c.entity.code == "AAAP001" }
      expect(ref_node.children.size).to eq(1)
      sub = ref_node.children.first
      expect(sub.entity).to be_a(Opencdd::Klass)
      expect(sub.entity.code).to eq("AAA010")
      expect(sub.children.map { |c| c.entity.code }).to eq(%w[AAAP101])
    end
  end

  describe "#for with definition_class pointing at a categorical class" do
    let(:db) do
      Opencdd::Database.new.tap do |d|
        categorical = Opencdd::Klass.new(
          irdi: Opencdd::IRDI.parse("AAA200"),
          properties: {
            "MDC_P001_5" => "AAA200",
            "MDC_P011"   => "CATEGORICAL_CLASS",
          },
          meta_class_irdi: Opencdd::IRDI.parse("MDC_C002"),
        )
        option_a = Opencdd::Klass.new(
          irdi: Opencdd::IRDI.parse("AAA201"),
          properties: { "MDC_P001_5" => "AAA201", "MDC_P010" => "AAA200", "MDC_P011" => "ITEM_CLASS" },
          meta_class_irdi: Opencdd::IRDI.parse("MDC_C002"),
        )
        option_b = Opencdd::Klass.new(
          irdi: Opencdd::IRDI.parse("AAA202"),
          properties: { "MDC_P001_5" => "AAA202", "MDC_P010" => "AAA200", "MDC_P011" => "ITEM_CLASS" },
          meta_class_irdi: Opencdd::IRDI.parse("MDC_C002"),
        )
        owner = Opencdd::Klass.new(
          irdi: Opencdd::IRDI.parse("AAA001"),
          properties: {
            "MDC_P001_5" => "AAA001",
            "MDC_P011"   => "ITEM_CLASS",
            "MDC_P014"   => "(AAAP001)",
          },
          meta_class_irdi: Opencdd::IRDI.parse("MDC_C002"),
        )
        optioned_prop = Opencdd::Property.new(
          irdi: Opencdd::IRDI.parse("AAAP001"),
          properties: {
            "MDC_P001_6" => "AAAP001",
            "MDC_P021"   => "AAA200",
            "MDC_P022"   => "STRING_TYPE",
          },
          meta_class_irdi: Opencdd::IRDI.parse("MDC_C003"),
        )
        d.add_entity(categorical)
        d.add_entity(option_a)
        d.add_entity(option_b)
        d.add_entity(owner)
        d.add_entity(optioned_prop)
        d.finalize!
      end
    end

    it "recurses into every subclass of the categorical class" do
      tree = described_class.new(db).for(db.find_by_code("AAA001"))
      prop_node = tree.children.first
      subclass_codes = prop_node.children.map { |c| c.entity.code }
      expect(subclass_codes).to contain_exactly("AAA201", "AAA202")
    end
  end

  describe "cycle detection" do
    it "stops recursion when a class is revisited on the current path" do
      db = Opencdd::Database.new
      meta_k = Opencdd::IRDI.parse("MDC_C002")
      meta_p = Opencdd::IRDI.parse("MDC_C003")
      a = Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse("AAA001"),
        properties: { "MDC_P001_5" => "AAA001", "MDC_P011" => "ITEM_CLASS", "MDC_P014" => "(AAAP001)" },
        meta_class_irdi: meta_k,
      )
      b = Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse("AAA002"),
        properties: { "MDC_P001_5" => "AAA002", "MDC_P011" => "ITEM_CLASS", "MDC_P014" => "(AAAP002)" },
        meta_class_irdi: meta_k,
      )
      p_a = Opencdd::Property.new(
        irdi: Opencdd::IRDI.parse("AAAP001"),
        properties: { "MDC_P001_6" => "AAAP001", "MDC_P022" => "CLASS_REFERENCE(AAA002)" },
        meta_class_irdi: meta_p,
      )
      p_b = Opencdd::Property.new(
        irdi: Opencdd::IRDI.parse("AAAP002"),
        properties: { "MDC_P001_6" => "AAAP002", "MDC_P022" => "CLASS_REFERENCE(AAA001)" },
        meta_class_irdi: meta_p,
      )
      [a, b, p_a, p_b].each { |e| db.add_entity(e) }
      db.finalize!

      tree = described_class.new(db).for(a)
      expect(tree.entity.code).to eq("AAA001")
      class_codes = tree.classes.map(&:code)
      expect(class_codes).to include("AAA001", "AAA002")
      expect(tree.depth).to be <= 5
      path_a_count = count_on_any_path(tree, "AAA001")
      expect(path_a_count).to be <= 2
    end

    it "honours max_depth as a hard stop" do
      db = Opencdd::Database.new
      meta_k = Opencdd::IRDI.parse("MDC_C002")
      meta_p = Opencdd::IRDI.parse("MDC_C003")
      a = Opencdd::Klass.new(
        irdi: Opencdd::IRDI.parse("AAA001"),
        properties: { "MDC_P001_5" => "AAA001", "MDC_P011" => "ITEM_CLASS", "MDC_P014" => "(AAAP001)" },
        meta_class_irdi: meta_k,
      )
      p = Opencdd::Property.new(
        irdi: Opencdd::IRDI.parse("AAAP001"),
        properties: { "MDC_P001_6" => "AAAP001", "MDC_P022" => "CLASS_REFERENCE(AAA001)" },
        meta_class_irdi: meta_p,
      )
      db.add_entity(a)
      db.add_entity(p)
      db.finalize!

      tree = described_class.new(db).for(a, max_depth: 0)
      expect(tree.children).to eq([])
      expect(tree.entity.code).to eq("AAA001")
    end
  end

  describe "Database#composition_tree entry point" do
    it "delegates to a CompositionTree instance" do
      vehicle = oceanrunner_db.find_by_code("AAA001")
      tree = oceanrunner_db.composition_tree(vehicle)
      expect(tree).to be_a(Opencdd::CompositionTree::Node)
      expect(tree.entity.code).to eq("AAA001")
    end
  end

  describe "OceanRunner integration" do
    it "emits Vehicle with three applicable properties as leaves" do
      vehicle = oceanrunner_db.find_by_code("AAA001")
      tree = oceanrunner_db.composition_tree(vehicle)
      expect(tree.entity.code).to eq("AAA001")
      expect(tree.children.map { |c| c.entity.code })
        .to contain_exactly("AAAP001", "AAAP002", "AAAP003")
    end

    it "recurses CLASS_REFERENCE into the categorical EngineType class for OceanRunner.engine_type" do
      oceanrunner = oceanrunner_db.find_by_code("BBB001")
      tree = oceanrunner_db.composition_tree(oceanrunner)
      engine_type_node = tree.children.find { |c| c.entity.code == "BBAP001" }
      expect(engine_type_node).not_to be_nil
      expect(engine_type_node.children.size).to eq(1)
      engine_type_class = engine_type_node.children.first
      expect(engine_type_class.entity).to be_a(Opencdd::Klass)
      expect(engine_type_class.entity.code).to eq("AAA200")
    end

    it "produces a non-empty tree for the configured ORCA30 product" do
      orca = oceanrunner_db.find_by_code("BBB100")
      tree = oceanrunner_db.composition_tree(orca)
      expect(tree.entity.code).to eq("BBB100")
      expect(tree.properties.map(&:code)).to include("BBAP001", "BBAP002", "BBAP003", "BBAP004")
    end
  end

  describe "resolution of unknown input" do
    it "returns nil for a class that cannot be resolved" do
      tree = described_class.new(oceanrunner_db).for("UNKNOWN_CODE_XYZ")
      expect(tree).to be_nil
    end
  end
end

def count_on_any_path(node, code, depth = 0)
  return 0 if depth > 100
  own = node.entity.is_a?(Opencdd::Klass) && node.entity.code == code ? 1 : 0
  child_counts = (node.children || []).map { |c| count_on_any_path(c, code, depth + 1) }
  own + (child_counts.empty? ? 0 : child_counts.max)
end
