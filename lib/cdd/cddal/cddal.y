# frozen_string_literal: true

class Cdd::Cddal::GeneratedParser

  expect 1    # one known shift/reduce conflict in import_item (IDENT vs IDENT soft_as IDENT)

  token META_CLASS INSTANCE ALIAS IMPORT TRUE FALSE NULL
        LBRACE RBRACE COLON COMMA LANGLE RANGLE DOT LPAREN RPAREN
        EQEQ NEQ
        STRING NUMBER DATE IRDI IDENT

rule

  document
    : /* empty */                    { result = Cdd::Cddal::AST::Document.new(declarations: []) }
    | document declaration           { val[0].declarations << val[1]; result = val[0] }
    ;

  declaration
    : meta_class_decl
    | instance_decl
    | alias_decl
    | import_decl
    ;

  meta_class_decl
    : META_CLASS ident_or_irdi opt_prop_list
        { result = Cdd::Cddal::AST::MetaClassDecl.new(irdi: val[1], property_identifiers: val[2] || [], line: lineno) }
    ;

  opt_prop_list
    : /* empty */                    { result = [] }
    | LBRACE prop_id_list RBRACE     { result = val[1] }
    ;

  prop_id_list
    : /* empty */                    { result = [] }
    | prop_id_list IDENT             { result = val[0] + [val[1]] }
    ;

  instance_decl
    : INSTANCE IDENT LANGLE ident_or_irdi opt_assignment_block
        { result = Cdd::Cddal::AST::InstanceDecl.new(
            name: val[1], meta_class_ref: val[3], assignments: val[4] || [], line: lineno) }
    | INSTANCE ident_or_irdi opt_assignment_block
        { result = Cdd::Cddal::AST::InstanceDecl.new(
            name: nil, meta_class_ref: val[1], assignments: val[2] || [], line: lineno) }
    ;

  opt_assignment_block
    : /* empty */                    { result = [] }
    | LBRACE assignment_list RBRACE  { result = val[1] }
    ;

  assignment_list
    : /* empty */                    { result = [] }
    | assignment_list assignment     { result = val[0] + [val[1]] }
    ;

  assignment
    : IDENT opt_language_tag COLON value
        { result = Cdd::Cddal::AST::PropertyAssignment.new(
            identifier: val[0], language_tag: val[1], value: val[3], line: lineno) }
    ;

  opt_language_tag
    : /* empty */                    { result = nil }
    | DOT IDENT                      { result = val[1] }
    ;

  alias_decl
    : ALIAS IDENT COLON ident_or_irdi
        { result = Cdd::Cddal::AST::AliasDecl.new(alias_name: val[1], property_id: val[3], line: lineno) }
    ;

  import_decl
    : IMPORT STRING
        { result = Cdd::Cddal::AST::ImportDecl.bare(val[1], line: lineno) }
    | IMPORT STRING soft_as IDENT
        { result = Cdd::Cddal::AST::ImportDecl.qualified(val[1], qualifier: val[3], line: lineno) }
    | soft_from STRING IMPORT LBRACE import_list RBRACE
        { result = Cdd::Cddal::AST::ImportDecl.selective(val[1], imported_names: val[4], line: lineno) }
    ;

  # Soft keywords. `as` and `from` are recognized by value at parse
  # time rather than lexed as keyword tokens, because they appear as
  # ordinary identifier values elsewhere (e.g. short_name.en: "as"
  # for attosecond). The action validates the IDENT value and raises
  # a ParseError if the soft keyword is misspelled.
  soft_as
    : IDENT
        {
          unless val[0] == "as"
            raise Racc::ParseError, "expected 'as' keyword, got #{val[0].inspect}"
          end
          result = val[0]
        }
    ;

  soft_from
    : IDENT
        {
          unless val[0] == "from"
            raise Racc::ParseError, "expected 'from' keyword, got #{val[0].inspect}"
          end
          result = val[0]
        }
    ;

  import_list
    : import_item                       { result = [val[0]] }
    | import_list COMMA import_item     { result = val[0] + [val[2]] }
    ;

  import_item
    : IDENT                             { result = Cdd::Cddal::AST::ImportedName.new(name: val[0]) }
    | IDENT soft_as IDENT               { result = Cdd::Cddal::AST::ImportedName.new(name: val[0], as: val[2]) }
    ;

  ident_or_irdi
    : IDENT                          { result = val[0] }
    | IRDI                           { result = val[0] }
    ;

  value
    : STRING                         { result = Cdd::Cddal::AST::Literal.new(kind: :string, raw: val[0]) }
    | NUMBER                         { result = Cdd::Cddal::AST::Literal.new(kind: :number, raw: val[0]) }
    | DATE                           { result = Cdd::Cddal::AST::Literal.new(kind: :date, raw: val[0]) }
    | TRUE                           { result = Cdd::Cddal::AST::Literal.new(kind: :boolean, raw: "true") }
    | FALSE                          { result = Cdd::Cddal::AST::Literal.new(kind: :boolean, raw: "false") }
    | NULL                           { result = Cdd::Cddal::AST::Literal.new(kind: :null, raw: "null") }
    | IRDI                           { result = Cdd::Cddal::AST::IdentifierRef.new(name: val[0]) }
    | condition
    | class_reference
    | dotted_ref
    | set
    | tuple
    | IDENT                          { result = Cdd::Cddal::AST::IdentifierRef.new(name: val[0]) }
    ;

  condition
    : IDENT cond_op condition_rhs
        { result = Cdd::Cddal::AST::Condition.new(left: val[0], operator: val[1], right: val[2]) }
    ;

  cond_op
    : EQEQ                           { result = "==" }
    | NEQ                            { result = "!=" }
    ;

  condition_rhs
    : STRING                         { result = Cdd::Cddal::AST::Literal.new(kind: :string, raw: val[0]) }
    | NUMBER                         { result = Cdd::Cddal::AST::Literal.new(kind: :number, raw: val[0]) }
    | IDENT                          { result = Cdd::Cddal::AST::IdentifierRef.new(name: val[0]) }
    | IRDI                           { result = Cdd::Cddal::AST::IdentifierRef.new(name: val[0]) }
    | set
    ;

  class_reference
    : IDENT LPAREN class_ref_arg RPAREN
        { result = Cdd::Cddal::AST::ClassReference.new(type_name: val[0], argument: val[2]) }
    ;

  class_ref_arg
    : IDENT                          { result = Cdd::Cddal::AST::IdentifierRef.new(name: val[0]) }
    | IRDI                           { result = Cdd::Cddal::AST::IdentifierRef.new(name: val[0]) }
    | STRING                         { result = Cdd::Cddal::AST::Literal.new(kind: :string, raw: val[0]) }
    ;

  dotted_ref
    : IDENT DOT IDENT
        { result = Cdd::Cddal::AST::IdentifierRef.new(name: val[2], owner: val[0]) }
    ;

  set
    : LBRACE RBRACE                  { result = Cdd::Cddal::AST::Set.new(elements: []) }
    | LBRACE set_element_list RBRACE { result = Cdd::Cddal::AST::Set.new(elements: val[1]) }
    ;

  set_element_list
    : set_element                    { result = [val[0]] }
    | set_element_list COMMA set_element { result = val[0] + [val[2]] }
    ;

  set_element
    : STRING                         { result = Cdd::Cddal::AST::Literal.new(kind: :string, raw: val[0]) }
    | NUMBER                         { result = Cdd::Cddal::AST::Literal.new(kind: :number, raw: val[0]) }
    | IRDI                           { result = Cdd::Cddal::AST::IdentifierRef.new(name: val[0]) }
    | class_reference
    | tuple
    | set
    | IDENT                          { result = Cdd::Cddal::AST::IdentifierRef.new(name: val[0]) }
    ;

  tuple
    : LPAREN tuple_element_list RPAREN
        { result = Cdd::Cddal::AST::Tuple.new(elements: val[1]) }
    ;

  tuple_element_list
    : tuple_element                  { result = [val[0]] }
    | tuple_element_list COMMA tuple_element { result = val[0] + [val[2]] }
    ;

  tuple_element
    : STRING                         { result = Cdd::Cddal::AST::Literal.new(kind: :string, raw: val[0]) }
    | NUMBER                         { result = Cdd::Cddal::AST::Literal.new(kind: :number, raw: val[0]) }
    | IRDI                           { result = Cdd::Cddal::AST::IdentifierRef.new(name: val[0]) }
    | IDENT                          { result = Cdd::Cddal::AST::IdentifierRef.new(name: val[0]) }
    ;

end

---- inner

def initialize(tokens)
  @tokens = tokens
  @pos = 0
end

def parse
  @tokens = @tokens.tokens if @tokens.is_a?(Cdd::Cddal::Lexer)
  do_parse
rescue Racc::ParseError => e
  raise Cdd::Cddal::ParseError, e.message
end

def next_token
  tok = @tokens[@pos]
  @pos += 1
  if tok.nil? || tok.kind == :EOF
    [false, false]
  else
    [tok.kind, tok.value]
  end
end

def lineno
  tok = @tokens[@pos]
  tok&.line || 0
end

def on_error(error_token_id, error_value, value_stack)
  tok = @tokens[@pos - 1]
  location = tok&.line ? " at line #{tok.line}" : ""
  token_name = token_to_str(error_token_id) || error_token_id.to_s
  raise Cdd::Cddal::ParseError,
    "unexpected #{token_name}(#{error_value.inspect})#{location}"
end
