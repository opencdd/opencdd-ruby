# frozen_string_literal: true

require "spec_helper"

# Real adapter for tests — satisfies the Resolver seam without
# touching the filesystem. Not a double; a real adapter.
class InMemoryResolver < Opencdd::Cddal::Resolver
  def initialize(mapping)
    @mapping = mapping
    super(strict: true)
  end

  def resolve(specifier, importing_file: nil)
    entry = @mapping[specifier.to_s]
    return [nil, nil] unless entry
    [entry[:canonical], entry[:source]]
  end
end

RSpec.describe Opencdd::Cddal::ImportPipeline do
  let(:database) { Opencdd::Database.new }

  it "processes an empty import list without error" do
    pipeline = described_class.new(
      database: database, resolver: Opencdd::Cddal::Resolver.new(strict: false),
      source_file: "test.cddal", loaded_modules: {}, loading_stack: [], qualified_table: {},
    )
    expect { pipeline.process([]) }.not_to raise_error
  end

  it "skips unresolvable imports gracefully in non-strict mode" do
    pipeline = described_class.new(
      database: database, resolver: Opencdd::Cddal::Resolver.new(strict: false),
      source_file: "test.cddal", loaded_modules: {}, loading_stack: [], qualified_table: {},
    )
    decl = Opencdd::Cddal::AST::ImportDecl.new(specifier: "nonexistent.cddal", kind: :bare)
    expect { pipeline.process([decl]) }.not_to raise_error
  end

  it "detects circular imports" do
    resolver = InMemoryResolver.new(
      "a.cddal" => { canonical: "/abs/a.cddal", source: "" },
    )
    pipeline = described_class.new(
      database: database, resolver: resolver,
      source_file: "/abs/a.cddal",
      loaded_modules: {}, loading_stack: ["/abs/a.cddal"], qualified_table: {},
    )
    decl = Opencdd::Cddal::AST::ImportDecl.new(specifier: "a.cddal", kind: :bare)
    expect { pipeline.process([decl]) }.to raise_error(Opencdd::Cddal::ImportError, /circular/)
  end

  it "imports a sub-module with valid CDDAL" do
    sub_source = <<~CDDAL
      instance SubClass < MDC_C002 {
        code: AAA999
        preferred_name.en: "Imported Class"
        class_type: ITEM_CLASS
      }
    CDDAL
    resolver = InMemoryResolver.new(
      "sub.cddal" => { canonical: "/abs/sub.cddal", source: sub_source },
    )
    pipeline = described_class.new(
      database: database, resolver: resolver,
      source_file: "/abs/main.cddal",
      loaded_modules: {}, loading_stack: [], qualified_table: {},
    )
    decl = Opencdd::Cddal::AST::ImportDecl.new(specifier: "sub.cddal", kind: :bare)
    pipeline.process([decl])
    expect(database.find_by_code("AAA999")).not_to be_nil
  end
end

