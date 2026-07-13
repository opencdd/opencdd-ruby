# frozen_string_literal: true

module Opencdd
  class IRDI
    FULL_REGEX = %r{
      \A
      (?<registrant>[^/#\s]+)
      /
      (?<semantic>[^/#\s]*)
      ///
      (?<scheme>[^/#\s]+)
      \#
      (?<code>[^#\s]+)
      (?:\#\#(?<smver>\d+))?
      \z
    }x

    SHORT_REGEX = /\A[^#\/\s]+\z/

    TREE_REGEX = %r{
      \A
      (?<registrant>[^-]+)
      -
      (?<semantic>[^-]*)
      ---
      (?<scheme>[^-]+)
      %23
      (?<code>[^%\s]+)
      \z
    }x

    attr_reader :registrant, :semantic, :scheme, :code, :version

    def self.parse(value)
      return nil if value.nil?
      s = value.to_s.strip
      return nil if s.empty?

      if (m = FULL_REGEX.match(s)) then from_match(m)
      elsif (m = TREE_REGEX.match(s)) then from_match(m)
      elsif SHORT_REGEX.match?(s) then from_short(s)
      elsif s.include?("#") && (m = FULL_REGEX.match(s.gsub(/\s+/, ""))) then from_match(m)
      else from_short(s)
      end
    end

    def self.from_short(code)
      new(registrant: nil, semantic: nil, scheme: nil, code: code.to_s)
    end

    def self.from_match(m)
      caps = m.named_captures.transform_keys(&:to_sym)
      new(
        registrant: caps[:registrant],
        semantic:   caps[:semantic],
        scheme:     caps[:scheme],
        code:       caps[:code],
        version:    caps[:smver],
      )
    end

    def initialize(registrant:, semantic:, scheme:, code:, version: nil)
      @registrant = registrant&.to_s
      @semantic   = semantic&.to_s
      @scheme     = scheme&.to_s
      @code       = code.to_s
      @version    = version&.to_s
      freeze
    end

    def full?
      !@registrant.nil?
    end

    def short?
      @registrant.nil?
    end

    alias_method :short, :code

    def sheetmap_version
      @version
    end

    def to_s
      return @code if short?
      "#{@registrant}/#{@semantic}///#{@scheme}##{@code}"
    end

    alias_method :to_str, :to_s

    def to_tree_path
      return @code if short?
      "#{@registrant}-#{@semantic}---#{@scheme}%23#{@code}"
    end

    def with_code(new_code)
      self.class.new(
        registrant: @registrant,
        semantic:   @semantic,
        scheme:     @scheme,
        code:       new_code.to_s,
        version:    @version,
      )
    end

    def eql?(other)
      other.is_a?(Opencdd::IRDI) && to_s == other.to_s
    end

    def hash
      to_s.hash
    end

    def ==(other)
      eql?(other)
    end

    def inspect
      "#<Opencdd::IRDI #{to_s.inspect}>"
    end

    def self.coerce(value)
      return value if value.is_a?(Opencdd::IRDI)
      parse(value)
    end
  end
end
