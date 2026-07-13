# frozen_string_literal: true

require "yaml"

module Opencdd
  module Exporters
    class Yaml < Json
      def to_yaml(database)
        reset!
        @nodes.clear
        visit_database(database)
        @nodes.to_yaml
      end
    end
  end
end
