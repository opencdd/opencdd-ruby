# frozen_string_literal: true

require "pathname"
require "digest"
require "tmpdir"

module Opencdd
  module Cddal
    module Fetcher
      # Default URL fetcher. Fetches via +Net::HTTP+, caches the
      # response body to +cache_dir+ keyed by URL hash, and supports
      # an +offline:+ mode that serves only cached content (used in
      # CI to keep test runs hermetic).
      class NetHttp
        attr_reader :cache_dir, :offline

        def initialize(cache_dir: default_cache_dir, offline: false)
          @cache_dir = cache_dir ? Pathname.new(cache_dir.to_s) : nil
          @offline = offline
          @memory_cache = {}
        end

        def fetch(url)
          key = url.to_s
          return @memory_cache[key] if @memory_cache.key?(key)

          text = if @offline
                   read_from_disk_cache(key) || raise_import_error(key)
                 else
                   fetch_http(key)
                 end

          @memory_cache[key] = text
          write_to_disk_cache(key, text) if @cache_dir && !@offline
          text
        end

        private

        def default_cache_dir
          ENV["CDDAL_CACHE"] || File.join(Dir.tmpdir, "cddal-cache")
        end

        def fetch_http(url)
          require "net/http"
          require "uri"
          uri = URI.parse(url)
          response = Net::HTTP.get_response(uri)
          unless response.is_a?(Net::HTTPSuccess)
            raise Opencdd::Cddal::ImportError,
                  "HTTP #{response.code} #{response.message} for #{url}"
          end
          response.body
        rescue Opencdd::Cddal::ImportError
          raise
        rescue StandardError => e
          raise Opencdd::Cddal::ImportError, "fetch failed for #{url}: #{e.message}"
        end

        def read_from_disk_cache(url)
          return nil unless @cache_dir
          path = cache_path_for(url)
          path.exist? ? path.read : nil
        end

        def write_to_disk_cache(url, text)
          path = cache_path_for(url)
          path.dirname.mkpath
          path.write(text) unless path.exist?
        end

        def cache_path_for(url)
          hash = Digest::SHA256.hexdigest(url)
          @cache_dir.join("#{hash}.cddal")
        end

        def raise_import_error(url)
          raise Opencdd::Cddal::ImportError,
                "offline mode and no cached copy for #{url}"
        end
      end
    end
  end
end
