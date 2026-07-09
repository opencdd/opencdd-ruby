# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::Visitor do
  let(:database) { Cdd::Cddal.parse_file(REFERENCE_DOCS.join("examples/oceanrunner.cddal")) }

  describe "#visit_database" do
    it "visits every class, property, and value_list in the database" do
      visitor = described_class.new
      visitor.visit_database(database)
      class_irdis = database.classes.map(&:irdi)
      property_irdis = database.properties.map(&:irdi)
      value_list_irdis = database.value_lists.map(&:irdi)
      expect(class_irdis.all? { |i| visitor.seen.include?(i) }).to be(true)
      expect(property_irdis.all? { |i| visitor.seen.include?(i) }).to be(true)
      expect(value_list_irdis.all? { |i| visitor.seen.include?(i) }).to be(true)
    end
  end

  describe "#visit_classes with hierarchy" do
    it "walks the entire class tree from roots" do
      visitor = described_class.new
      visitor.visit_classes(database)
      expect(visitor.seen.size).to eq(database.classes.size)
    end
  end

  describe "#visit_class cycle detection" do
    it "stops when a cycle is encountered" do
      db = Cdd::Database.new
      meta = Cdd::IRDI.parse("MDC_C002")
      a = Cdd::Klass.new(
        irdi: Cdd::IRDI.parse("CYC001"),
        properties: { "MDC_P010" => "CYC002" },
        meta_class_irdi: meta,
      )
      b = Cdd::Klass.new(
        irdi: Cdd::IRDI.parse("CYC002"),
        properties: { "MDC_P010" => "CYC001" },
        meta_class_irdi: meta,
      )
      db.add_entity(a)
      db.add_entity(b)
      db.finalize!

      visitor = described_class.new
      visitor.visit_class(a)
      expect(visitor.seen).to include(a.irdi, b.irdi)
    end
  end

  describe "#reset!" do
    it "clears the seen set" do
      visitor = described_class.new
      visitor.visit_database(database)
      expect(visitor.seen).not_to be_empty
      visitor.reset!
      expect(visitor.seen).to be_empty
    end
  end

  describe "subclasses overriding visit_class" do
    it "lets a subclass collect nodes via super" do
      collector = Class.new(described_class) do
        attr_reader :visited

        def initialize
          super
          @visited = []
        end

        def visit_class(klass)
          @visited << klass.code
          super
        end
      end.new

      collector.visit_classes(database)
      expect(collector.visited).to include("AAA001", "AAA010", "AAA100", "BBB001")
    end
  end
end
