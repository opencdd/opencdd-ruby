# frozen_string_literal: true

module Opencdd
  class ViewControl < Opencdd::Entity
    # ── Pure field reads ─────────────────────────────────────────
    field :controlled_class_irdis, "EXT_P002", as: "controlled_classes"
    field :shown_property_irdis,   "EXT_P003", as: "shown_properties"
    # data_object_identifier and time_stamp inherited from Entity base.
  end
end
