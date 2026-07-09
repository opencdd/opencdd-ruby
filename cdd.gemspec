# frozen_string_literal: true

require_relative "lib/cdd/version"

Gem::Specification.new do |spec|
  spec.name = "cdd"
  spec.version = Cdd::VERSION
  spec.authors = ["OpenCDD contributors"]
  spec.email   = ["cdd@opencdd.org"]
  spec.summary = "Ruby model and Parcel-format importer for the IEC Common Data Dictionary"
  spec.description = <<~DESC
    Cdd is a pure-Ruby library that models the IEC Common Data Dictionary
    (IEC 61360 / CDD ontology), supports power-type semantics where instances
    can themselves be used as classes, and imports the Parcel Excel workbook
    format (both ParcelMaker .xlsx and the legacy 6-file .xls export layout)
    into a navigable in-memory database.
  DESC
  spec.homepage = "https://github.com/opencdd/cdd-data"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*.rb", "*.md", "LICENSE*", "bin/*"].reject { |f| File.directory?(f) }
  end
  spec.require_paths = ["lib"]
  spec.bindir = "bin"
  spec.executables = []  # bin/console, bin/smoke are dev helpers, not installed

  spec.add_dependency "roo",        "~> 2.10"
  spec.add_dependency "rubyzip",    ">= 2.3"
  spec.add_dependency "spreadsheet", "~> 1.3"
  spec.add_dependency "base64",     ">= 0.2"
  spec.add_dependency "bigdecimal", ">= 3.1"
  spec.add_dependency "csv",        "~> 3.3"

  spec.add_development_dependency "rake",       "~> 13.0"
  spec.add_development_dependency "rspec",      "~> 3.13"
  spec.add_development_dependency "rspec-its",  "~> 1.3"
end
