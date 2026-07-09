# frozen_string_literal: true

require "strscan"

module Cdd
  module Cddal
    Token = Struct.new(:kind, :value, :line, :column, keyword_init: true) do
      def inspect
        "#{kind}#{value && !value.empty? ? "(#{value.inspect})" : ""}@#{line}:#{column}"
      end
    end

    class Lexer
      PUNCTUATION = {
        "{" => :LBRACE, "}" => :RBRACE,
        ":" => :COLON,  "," => :COMMA,
        "<" => :LANGLE, ">" => :RANGLE,
        "." => :DOT,
        "(" => :LPAREN, ")" => :RPAREN,
      }.freeze

      KEYWORD_MAP = {
        "instance" => :INSTANCE,
        "alias"    => :ALIAS,
        "import"   => :IMPORT,
        "true"     => :TRUE,
        "false"    => :FALSE,
        "null"     => :NULL,
      }.freeze

      IRDI_RE         = /[0-9]+\/[0-9]+\/\/\/[A-Za-z0-9_]+(?:_[0-9]+)?#[A-Za-z0-9_]+/.freeze
      LOCAL_REF_RE    = /[A-Za-z_][A-Za-z0-9_]*#[A-Za-z0-9_]+(?:##[A-Za-z0-9_]+)?/.freeze
      DATE_RE         = /\d{4}-\d{2}-\d{2}/.freeze
      NUMBER_RE       = /-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/.freeze
      IDENT_RE        = /[A-Za-z_][A-Za-z0-9_]*/.freeze
      META_CLASS_RE   = /(?:property-meta-class|enumeration-meta-class|term-meta-class|meta-class)(?![A-Za-z0-9_-])/.freeze
      WS_RE           = /[ \t\r]+/.freeze
      NEWLINE_RE      = /\n/.freeze
      COMMENT_RE      = /#[^\n]*/.freeze

      attr_reader :source

      def initialize(source)
        @source = source.to_s
        @ss = StringScanner.new(@source)
        @line = 1
        @col = 1
      end

      def tokens
        return @tokens if @tokens
        @tokens = []
        until @ss.eos?
          skip_interstitial
          break if @ss.eos?
          tok = scan_token
          raise LexError, "unexpected character #{@ss.peek(1).inspect} at line #{@line}, column #{@col}" unless tok
          @tokens << tok
        end
        @tokens << Token.new(kind: :EOF, value: "", line: @line, column: @col)
        @tokens
      end

      def next_token
        tok = tokens[@pos || 0]
        @pos = (@pos || 0) + 1
        tok ? [tok.kind, tok.value] : [false, false]
      end

      private

      def skip_interstitial
        loop do
          if ws = @ss.scan(WS_RE)
            @col += ws.length
          elsif @ss.scan(NEWLINE_RE)
            @line += 1
            @col = 1
          elsif comment = @ss.scan(COMMENT_RE)
            @col += comment.length
          else
            break
          end
        end
      end

      def scan_token
        line = @line
        col = @col

        if @ss.peek(1) == '"'
          value = scan_string_literal
          return Token.new(kind: :STRING, value: value, line: line, column: col)
        end

        if op = @ss.scan(/==|!=/)
          @col += op.length
          return Token.new(kind: op == "==" ? :EQEQ : :NEQ, value: op, line: line, column: col)
        end

        char = @ss.peek(1)
        if PUNCTUATION.key?(char)
          @ss.getch
          @col += 1
          return Token.new(kind: PUNCTUATION[char], value: char, line: line, column: col)
        end

        if mc = @ss.scan(META_CLASS_RE)
          @col += mc.length
          return Token.new(kind: :META_CLASS, value: mc, line: line, column: col)
        end

        if irdi = @ss.scan(IRDI_RE)
          @col += irdi.length
          return Token.new(kind: :IRDI, value: irdi, line: line, column: col)
        end

        if local = @ss.scan(LOCAL_REF_RE)
          @col += local.length
          return Token.new(kind: :IDENT, value: local, line: line, column: col)
        end

        if date = @ss.scan(DATE_RE)
          unless @ss.peek(1) =~ /[A-Za-z_]/
            @col += date.length
            return Token.new(kind: :DATE, value: date, line: line, column: col)
          end
          @ss.pos -= date.length
        end

        if num = @ss.scan(NUMBER_RE)
          @col += num.length
          return Token.new(kind: :NUMBER, value: num, line: line, column: col)
        end

        if ident = @ss.scan(IDENT_RE)
          @col += ident.length
          kind = KEYWORD_MAP[ident] || :IDENT
          return Token.new(kind: kind, value: ident, line: line, column: col)
        end

        nil
      end

      def scan_string_literal
        @ss.getch
        buffer = +""
        until @ss.eos?
          ch = @ss.getch
          case ch
          when '"'
            @col += buffer.length + 2
            return buffer
          when "\\"
            esc = @ss.getch
            raise LexError, "unterminated escape at line #{@line}" unless esc
            buffer << decode_escape(esc)
          when "\n"
            raise LexError, "unterminated string at line #{@line}"
          else
            buffer << ch
          end
        end
        raise LexError, "unterminated string at line #{@line}"
      end

      def decode_escape(esc)
        case esc
        when '"'  then '"'
        when "\\" then "\\"
        when "/"  then "/"
        when "b"  then "\b"
        when "f"  then "\f"
        when "n"  then "\n"
        when "r"  then "\r"
        when "t"  then "\t"
        when "u"
          hex = @ss.scan(/[0-9a-fA-F]{4}/)
          raise LexError, "invalid unicode escape at line #{@line}" unless hex
          [hex.to_i(16)].pack("U")
        else
          raise LexError, "invalid escape \\#{esc} at line #{@line}"
        end
      end
    end
  end
end
