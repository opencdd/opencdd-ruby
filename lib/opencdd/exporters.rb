# frozen_string_literal: true

module Opencdd
  module Exporters
    autoload :Json,    "opencdd/exporters/json"
    autoload :Yaml,    "opencdd/exporters/yaml"
    autoload :Mermaid, "opencdd/exporters/mermaid"
  end
end
