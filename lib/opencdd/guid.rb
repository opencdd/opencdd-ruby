# frozen_string_literal: true

require "securerandom"

module Opencdd
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
      # Use the field-access seam so writes go through canonical-id
      # resolution. Keeps GUID writes consistent with reads and
      # avoids bypassing the Field DSL.
      entity.write_property!(Opencdd::PropertyIds::MDC_P066, guid)
      guid
    end
  end
end
