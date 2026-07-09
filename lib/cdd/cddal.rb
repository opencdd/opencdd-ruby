# frozen_string_literal: true

module Cdd
  module Cddal
    autoload :Lexer,           "cdd/cddal/lexer"
    autoload :AST,             "cdd/cddal/ast"
    autoload :Parser,          "cdd/cddal/parser"
    autoload :GeneratedParser, "cdd/cddal/generated_parser"
    autoload :Builder,         "cdd/cddal/builder"
    autoload :Serializer,      "cdd/cddal/serializer"

    class Error < StandardError; end
    class LexError < Error; end
    class ParseError < Error; end
    class ResolutionError < Error; end

    module_function

    def parse(source, database: nil)
      tokens = Lexer.new(source).tokens
      declarations = Parser.new(tokens).parse
      Builder.new(database).build(declarations)
    end

    def parse_file(path, database: nil)
      parse(File.read(path), database: database)
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
