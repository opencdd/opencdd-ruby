# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::RelationTree do
  def make_relation(code, super_code = nil, meta_class_irdi: "MDC_C011")
    props = {
      Cdd::PropertyIds::MDC_P001_5 => code,
    }
    props[Cdd::PropertyIds::MDC_P212] = super_code if super_code
    Cdd::Relation.new(
      irdi: Cdd::IRDI.parse("0112/2///62683##{code}"),
      properties: props,
      meta_class_irdi: Cdd::IRDI.parse(meta_class_irdi),
    )
  end

  def make_database(*relations)
    Cdd::Database.new.tap do |d|
      relations.each { |r| d.add_entity(r) }
      d.finalize!
    end
  end

  describe "single relation with no super" do
    let(:db) { make_database(make_relation("REL001")) }

    it "produces a root-level node with no children" do
      tree = db.relation_tree
      expect(tree.size).to eq(1)
      node = tree.first
      expect(node.relation.code).to eq("REL001")
      expect(node.children).to be_empty
    end
  end

  describe "parent → child edge" do
    let(:db) { make_database(make_relation("REL001"), make_relation("REL002", "REL001")) }

    it "builds parent → child tree" do
      tree = db.relation_tree
      expect(tree.size).to eq(1)
      root = tree.first
      expect(root.relation.code).to eq("REL001")
      expect(root.children.size).to eq(1)
      expect(root.children.first.relation.code).to eq("REL002")
    end
  end

  describe "three-level chain" do
    let(:db) do
      make_database(
        make_relation("REL001"),
        make_relation("REL002", "REL001"),
        make_relation("REL003", "REL002"),
      )
    end

    it "builds depth-3 tree" do
      tree = db.relation_tree
      expect(tree.first.depth).to eq(3)
    end
  end

  describe "cycle detection" do
    let(:db) do
      make_database(
        make_relation("REL001"),
        make_relation("REL002", "REL001"),
        make_relation("REL003", "REL002"),
      ).tap do |d|
        rel1 = d.find_by_code("REL001")
        rel1.properties[Cdd::PropertyIds::MDC_P212] = "REL003"
      end
    end

    it "does not infinite-loop" do
      expect { db.relation_tree }.not_to raise_error
      expect { db.relation_tree(max_depth: 5) }.not_to raise_error
    end
  end

  describe "root parameter" do
    let(:db) do
      make_database(
        make_relation("REL001"),
        make_relation("REL002", "REL001"),
        make_relation("REL003"),
      )
    end

    it "limits walk to subtree" do
      tree = db.relation_tree("REL001")
      expect(tree.size).to eq(1)
      expect(tree.first.relation.code).to eq("REL001")
      expect(tree.first.children.first.relation.code).to eq("REL002")
    end
  end

  describe "max_depth" do
    let(:db) do
      make_database(
        make_relation("REL001"),
        make_relation("REL002", "REL001"),
        make_relation("REL003", "REL002"),
      )
    end

    it "stops at max_depth" do
      tree = db.relation_tree(max_depth: 2)
      expect(tree.first.depth).to eq(2)
    end
  end

  describe "Node enumerable" do
    let(:db) do
      make_database(
        make_relation("REL001"),
        make_relation("REL002", "REL001"),
      )
    end

    it "iterates all nodes" do
      tree = db.relation_tree
      codes = tree.flat_map { |node| node.map { |n| n.relation.code } }
      expect(codes).to contain_exactly("REL001", "REL002")
    end
  end
end
