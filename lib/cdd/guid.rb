# frozen_string_literal: true

require "securerandom"

module Cdd
  module GUID
    PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i.freeze

    def self.generate
      SecureRandom.uuid
    end

    def self.valid?(value)
      return false unless value.is_a?(String)
      PATTERN.match?(value)
    end

    def self.set_on(entity)
      guid = generate
      entity.properties[Cdd::PropertyIds::MDC_P066] = guid
      guid
    end
  end
end
