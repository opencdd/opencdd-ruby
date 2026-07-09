# frozen_string_literal: true

module Cdd
  class ViewControl < Cdd::Entity
    # ── Pure field reads ─────────────────────────────────────────
    field :controlled_class_irdis, "EXT_P002"
    field :shown_property_irdis,   "EXT_P003"
    # data_object_identifier and time_stamp inherited from Entity base.
  end
end
