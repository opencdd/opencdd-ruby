# frozen_string_literal: true

require "cdd"

RSpec.describe "Cdd::Entity field DSL" do
  # Test fixtures use a fresh subclass so we don't pollute Cdd::Entity.
  let(:klass) do
    Class.new(Cdd::Entity) do
      def self.name = "Cdd::EntityDSLTestKlass" # for FieldRegistry lookup
      field :code_value, "MDC_P001_5", :string
      field :short_name, "MDC_P005", :string, multilingual: true
      field :superclass_ref, "MDC_P010", :irdi
      field :case_of, "MDC_P013", :set_of_refs
    end
  end

  def entity(props)
    klass.new(
      irdi: Cdd::IRDI.parse("0112/2///61360_4#AAA001"),
      properties: props,
      meta_class_irdi: nil,
    )
  end

  it "registers fields with their metadata" do
    fields = Cdd::Entity::FieldRegistry.fields_for(klass).map(&:name)
    expect(fields).to include(:code_value, :short_name, :superclass_ref, :case_of)
  end

  it "generates a reader for scalar fields" do
    e = entity("MDC_P001_5" => "AAA001")
    expect(e.code_value).to eq("AAA001")
  end

  it "returns nil for missing fields" do
    e = entity({})
    expect(e.code_value).to be_nil
  end

  it "reads the source-language value for multilingual fields" do
    e = entity("MDC_P005" => "VTA")
    expect(e.short_name).to eq("VTA")
  end

  it "reads a specific language with source-language fallback" do
    e = entity("MDC_P005.en" => "VTA", "MDC_P005.de" => "Spannungsverstärker")
    expect(e.short_name(:de)).to eq("Spannungsverstärker")
    expect(e.short_name(:fr)).to eq("VTA") # falls back to source
  end

  it "parses IRDI values via the :irdi kind" do
    e = entity("MDC_P010" => "0112/2///61360_4#AAA000")
    expect(e.superclass_ref).to be_a(Cdd::IRDI)
    expect(e.superclass_ref.to_s).to eq("0112/2///61360_4#AAA000")
  end

  it "parses set_of_refs into an array of IRDIs" do
    e = entity("MDC_P013" => "{0112/2///61360_4#AAA100,0112/2///61360_4#AAA101}")
    refs = e.case_of
    expect(refs.length).to eq(2)
    expect(refs.first).to be_a(Cdd::IRDI)
  end

  it "returns an empty array for empty set_of_refs" do
    e = entity("MDC_P013" => "")
    expect(e.case_of).to eq([])
  end

  it "supports synthetic fields with a custom reader" do
    k = Class.new(Cdd::Entity) do
      def self.name = "Cdd::EntityDLSyntheticTest"
      field :computed, nil, :string, synthetic: true, reader: :read_computed

      def read_computed
        "synthetic-value"
      end
    end
    e = k.new(irdi: nil, properties: {}, meta_class_irdi: nil)
    expect(e.computed).to eq("synthetic-value")
  end

  it "is open for extension — adding a field doesn't edit Entity" do
    # Adding a field to a subclass is the only required step.
    expect(klass.new(irdi: nil, properties: {}, meta_class_irdi: nil))
      .to respond_to(:code_value, :short_name)
  end
end
