# frozen_string_literal: true

require "spec_helper"

RSpec.describe Cdd::Relation, "extended accessors" do
  let(:meta) { Cdd::IRDI.parse("0112/2///62656_1#MDC_C011") }

  let(:schema) do
    Cdd::Parcel::SheetSchema.from_header_rows([
      ["#PROPERTY_ID", "MDC_P001_13", "MDC_P200", "MDC_P201", "MDC_P202", "MDC_P203", "MDC_P204", "MDC_P205", "MDC_P206", "MDC_P207", "MDC_P208", "MDC_P209", "MDC_P210", "MDC_P211", "MDC_P212"],
      ["#PROPERTY_NAME.en", "Code", "Relation type", "Domain", "Domain of function", "Codomain", "Formula", "Formula lang", "Solver", "Trigger", "Domain element", "Codomain element", "Role", "Segment", "Super relation"],
      ["#DATATYPE"] + ["STRING_TYPE", "ICID_STRING", "ICID_STRING", "ICID_STRING", "ICID_STRING", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE", "STRING_TYPE", "ICID_STRING"],
    ])
  end

  let(:row) do
    {
      "MDC_P001_13" => "0112/2///62683#ACK001",
      "MDC_P200"    => "PREDICATION",
      "MDC_P201"    => "0112/2///62683#ACE001",
      "MDC_P202"    => "0112/2///62683#ACE002",
      "MDC_P203"    => "0112/2///62683#ACI001",
      "MDC_P204"    => "a + b",
      "MDC_P205"    => "MathML",
      "MDC_P206"    => "solver.py",
      "MDC_P207"    => "value_change",
      "MDC_P208"    => "ITEM_CLASS",
      "MDC_P209"    => "VALUE_CLASS",
      "MDC_P210"    => "owner",
      "MDC_P211"    => "main",
      "MDC_P212"    => "0112/2///62683#ACK000",
    }
  end

  subject(:relation) do
    described_class.from_row(row, schema: schema, meta_class_irdi: meta)
  end

  describe "domain and codomain" do
    it "combines MDC_P201 and MDC_P202 into domain_irdis" do
      expect(relation.domain_irdis.map(&:to_s))
        .to eq(["0112/2///62683#ACE001", "0112/2///62683#ACE002"])
    end

    it "exposes domain_of_function_irdis from MDC_P202" do
      expect(relation.domain_of_function_irdis.map(&:to_s))
        .to eq(["0112/2///62683#ACE002"])
    end

    it "parses codomain_irdi from MDC_P203" do
      expect(relation.codomain_irdi.to_s).to eq("0112/2///62683#ACI001")
    end
  end

  describe "formula and metadata" do
    its(:formula) { should eq("a + b") }
    its(:formula_language) { should eq("MathML") }
    its(:external_solver) { should eq("solver.py") }
    its(:trigger_event) { should eq("value_change") }
    its(:domain_element_type) { should eq("ITEM_CLASS") }
    its(:codomain_element_type) { should eq("VALUE_CLASS") }
    its(:role) { should eq("owner") }
    its(:segment) { should eq("main") }

    it "parses super_relation_irdi from MDC_P212" do
      expect(relation.super_relation_irdi.to_s).to eq("0112/2///62683#ACK000")
    end
  end

  describe "relation type predicates" do
    describe "predication" do
      it { expect(relation).to be_predication }
      it { expect(relation).not_to be_function }
    end

    describe "function" do
      subject(:function) do
        described_class.from_row(
          row.merge("MDC_P200" => "FUNCTION"),
          schema: schema, meta_class_irdi: meta,
        )
      end

      it { expect(function).to be_function }
      it { expect(function).not_to be_predication }
    end
  end

  describe "relation_type object" do
    it "returns a Cdd::RelationType" do
      expect(relation.relation_type).to be_a(Cdd::RelationType)
    end

    it "exposes a symbol form" do
      expect(relation.relation_type_symbol).to eq(:predication)
    end
  end
end
