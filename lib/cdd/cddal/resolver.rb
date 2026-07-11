# frozen_string_literal: true

require "pathname"

module Cdd
  module Cddal
    # Resolves a CDDAL module specifier to a canonical key and source
    # text. The canonical key (absolute path or normalized URL) is
    # used by the Builder to deduplicate imports — the same module
    # imported twice loads only once.
    #
    # Resolution rules, in priority order:
    #
    #   1. URL (http://, https://, file://) — fetched via the
    #      configured Fetcher. URL is the canonical key.
    #   2. Absolute filesystem path — read directly. Expanded path
    #      is the canonical key.
    #   3. Relative path (starts with ./ or ../) — resolved against
    #      the importing file's directory, falling back to base_path.
    #   4. Bare name — searched in search_path entries, then
    #      base_path. First match wins.
    #
    # When +strict:+ is false (default), URL fetch failures and
    # missing paths emit a warning and return +[nil, nil]+ so the
    # Builder can skip them. When +strict:+ is true, raises
    # +Cdd::Cddal::ImportError+ on any resolution failure.
    class Resolver
      DEFAULT_SEARCH_PATH = [Pathname.pwd].freeze

      attr_reader :base_path, :search_path, :fetcher, :strict

      def initialize(base_path: nil, search_path: nil, fetcher: nil, strict: false)
        @base_path   = base_path ? Pathname.new(base_path) : Pathname.pwd
        @search_path = Array(search_path).map { |p| Pathname.new(p.to_s) }
        @fetcher     = fetcher || Cdd::Cddal::Fetcher::NetHttp.new
        @strict      = strict
      end

      # Returns a tuple +[canonical_key, source_text]+. Returns
      # +[nil, nil]+ in non-strict mode when resolution fails.
      def resolve(specifier, importing_file: nil)
        specifier = specifier.to_s
        return resolve_url(specifier) if url?(specifier)

        resolve_path(specifier, importing_file)
      rescue Cdd::Cddal::ImportError => e
        raise if @strict

        warn "CDDAL: #{e.message}" if $VERBOSE || ENV["CDDAL_DEBUG"]
        [nil, nil]
      end

      private

      def url?(s)
        s.start_with?("http://", "https://", "file://")
      end

      def resolve_url(url)
        text = @fetcher.fetch(url)
        [url, text]
      end

      def resolve_path(spec, importing_file)
        p = Pathname.new(spec)
        candidates = path_candidates(p, importing_file)
        candidates.uniq.each do |cand|
          return [cand.expand_path.to_s, cand.read] if cand.exist? && cand.file?
        end
        raise Cdd::Cddal::ImportError,
              "cannot resolve import #{spec.inspect} " \
              "(searched: #{candidates.map(&:to_s).join(', ')})"
      end

      def path_candidates(p, importing_file)
        if p.absolute?
          [p]
        elsif spec_relative?(p)
          base = importing_file ? Pathname.new(importing_file).dirname : @base_path
          [base.join(p)]
        else
          # Bare name: walk search path, then base.
          @search_path.map { |sp| sp.join(p) } + [@base_path.join(p)]
        end
      end

      def spec_relative?(p)
        s = p.to_s
        s.start_with?("./", "../")
      end
    end
  end
end
