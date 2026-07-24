# frozen_string_literal: true

# Back-compat shim. The canonical entry is `require "opencdd"`.
# `require "cdd"` continues to work for callers that haven't been
# updated yet, but new code should require "opencdd" directly.
require "opencdd"

# Alias for backward compatibility. The module was renamed from
# Cdd to Opencdd, but many callers (data-private Rakefile, specs, etc.)
# still reference Cdd::. This alias lets them keep working.
Cdd = Opencdd unless defined?(Cdd)
