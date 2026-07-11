# frozen_string_literal: true

require "pathname"
require "digest"

module Cdd
  module Cddal
    # Pluggable fetcher for URL-based CDDAL imports. The default
    # +NetHttp+ implementation honors an on-disk cache and an
    # +offline:+ flag (used in CI to avoid network dependence).
    # Tests use +InMemory+ to stub URL fetching without touching
    # the network.
    module Fetcher
      autoload :NetHttp,   "cdd/cddal/fetcher/net_http"
      autoload :InMemory,  "cdd/cddal/fetcher/in_memory"
    end
  end
end
