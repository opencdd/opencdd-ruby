# frozen_string_literal: true

# The gem is named +opencdd+ on RubyGems, but the Ruby module is
# +Cdd+ (kept for code stability — the module name appears in every
# class path: Cdd::Entity, Cdd::Klass, Cdd::Property, etc.).
#
# Both +require "opencdd"+ and +require "cdd"+ work. The canonical
# entry point is lib/cdd.rb which defines the autoload tree.
require "cdd"
