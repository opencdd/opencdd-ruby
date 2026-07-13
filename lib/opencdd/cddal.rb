# frozen_string_literal: true

module Opencdd
  module Cddal
    autoload :Lexer,           "opencdd/cddal/lexer"
    autoload :AST,             "opencdd/cddal/ast"
    autoload :Parser,          "opencdd/cddal/parser"
    autoload :GeneratedParser, "opencdd/cddal/generated_parser"
    autoload :Builder,         "opencdd/cddal/builder"
    autoload :Serializer,      "opencdd/cddal/serializer"
    autoload :Resolver,        "opencdd/cddal/resolver"
    autoload :Fetcher,         "opencdd/cddal/fetcher"
    autoload :ValueSerializer, "opencdd/cddal/value_serializer"

    class Error < StandardError; end
    class LexError < Error; end
    class ParseError < Error; end
    class ResolutionError < Error; end
    class ImportError < Error; end

    @default_resolver = nil

    module_function

    def default_resolver
      @default_resolver ||= Resolver.new
    end

    # Parse +source+ (a CDDAL string) into a +Opencdd::Database+.
    #
    # Options:
    #   database: - existing Database to merge into (default: new)
    #   resolver: - Opencdd::Cddal::Resolver for module imports
    #               (default: a fresh Resolver with default fetcher)
    #   fetcher:  - shortcut; if supplied, wraps in a new Resolver
    #   source_file: - path/URL the source came from. Used for
    #               diagnostics and for resolving relative imports.
    def parse(source, database: nil, resolver: nil, fetcher: nil,
              source_file: nil)
      tokens = Lexer.new(source.to_s).tokens
      declarations = Parser.new(tokens).parse
      effective_resolver =
        resolver || (fetcher ? Resolver.new(fetcher: fetcher) : default_resolver)
      Builder.new(database, resolver: effective_resolver, source_file: source_file)
        .build(declarations)
    end

    def parse_file(path, database: nil, resolver: nil, fetcher: nil)
      source = File.read(path)
      parse(source, database: database,
            resolver: resolver, fetcher: fetcher, source_file: path)
    end

    def serialize(database)
      Serializer.new(database).to_cddal
    end

    def serialize_to_file(database, path)
      File.write(path, serialize(database))
      self
    end
  end
end
