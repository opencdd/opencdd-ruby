# frozen_string_literal: true

module Opencdd
  module Cddal
    module Fetcher
      # Test fetcher. Holds an in-memory URL → source map; specs
      # construct one with the fixtures they want to serve. Avoids
      # any network dependency in the test suite.
      class InMemory
        attr_reader :map

        def initialize(map = {})
          @map = {}
          map.each { |k, v| @map[k.to_s] = v.to_s }
        end

        def fetch(url)
          key = url.to_s
          @map.fetch(key) do
            raise Opencdd::Cddal::ImportError,
                  "no in-memory fixture registered for #{key}"
          end
        end

        def register(url, source)
          @map[url.to_s] = source.to_s
          self
        end
      end
    end
  end
end
