# frozen_string_literal: true

require "spec_helper"

RSpec.describe Opencdd::StructuredValues, ".unwrap_and_split" do
  it "returns [] for nil" do
    expect(described_class.unwrap_and_split(nil)).to eq([])
  end

  it "returns [] for empty/whitespace" do
    expect(described_class.unwrap_and_split("")).to eq([])
    expect(described_class.unwrap_and_split("   ")).to eq([])
  end

  it "splits an unwrapped comma list" do
    expect(described_class.unwrap_and_split("a,b,c")).to eq(%w[a b c])
  end

  it "strips {} wrappers" do
    expect(described_class.unwrap_and_split("{a,b,c}")).to eq(%w[a b c])
  end

  it "strips () wrappers" do
    expect(described_class.unwrap_and_split("(a,b,c)")).to eq(%w[a b c])
  end

  it "strips whitespace around elements" do
    expect(described_class.unwrap_and_split("{ a , b , c }")).to eq(%w[a b c])
  end

  it "rejects empty elements" do
    expect(described_class.unwrap_and_split("a,,b")).to eq(%w[a b])
    expect(described_class.unwrap_and_split("a, ,b")).to eq(%w[a b])
  end

  it "handles trailing comma" do
    expect(described_class.unwrap_and_split("a,b,")).to eq(%w[a b])
  end

  it "preserves nested tuples" do
    expect(described_class.unwrap_and_split("{(a,b),(c,d)}")).to eq(["(a,b)", "(c,d)"])
  end

  it "preserves nested sets" do
    expect(described_class.unwrap_and_split("{{x,y},{z}}")).to eq(["{x,y}", "{z}"])
  end

  it "handles IRDI sets" do
    input = "{0112/2///62656_1#AAA001,0112/2///62656_1#AAA002}"
    expect(described_class.unwrap_and_split(input).size).to eq(2)
  end

  it "returns [] for empty braces" do
    expect(described_class.unwrap_and_split("{}")).to eq([])
  end
end

RSpec.describe Opencdd::StructuredValues, ".rejoin" do
  it "returns '' for nil/empty input" do
    expect(described_class.rejoin(nil)).to eq("")
    expect(described_class.rejoin([])).to eq("")
  end

  it "wraps a single element in braces" do
    expect(described_class.rejoin(["a"])).to eq("{a}")
  end

  it "joins multiple elements with comma, no space" do
    expect(described_class.rejoin(%w[a b c])).to eq("{a,b,c}")
  end

  it "rejects empty/blank elements" do
    expect(described_class.rejoin(["a", "", "b"])).to eq("{a,b}")
    expect(described_class.rejoin(["a", "  ", "b"])).to eq("{a,b}")
  end

  it "coerces non-string elements via to_s" do
    expect(described_class.rejoin([1, 2, 3])).to eq("{1,2,3}")
  end
end

RSpec.describe "round-trip unwrap_and_split → rejoin" do
  it "preserves membership for sets" do
    input = "{0112/2///62656_1#AAA001, 0112/2///62656_1#AAA002}"
    elements = Opencdd::StructuredValues.unwrap_and_split(input)
    rejoined = Opencdd::StructuredValues.rejoin(elements)
    reelements = Opencdd::StructuredValues.unwrap_and_split(rejoined)
    expect(reelements.sort).to eq(elements.sort)
  end
end
