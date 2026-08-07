# frozen_string_literal: true

module Opencdd
  class DetClassification < Opencdd::Entity
    # The cdd.iec.ch search-export DET classification .xls stores the
    # entity code as a short string (e.g. "A11") in column 1. We
    # need to synthesize the full IRDI by prepending the meta-class's
    # supplier prefix (IECCDD_001) — the standard from_row would
    # IRDI.parse("A11") which fails (no namespace).
    DET_CLASSIFICATION_SUPPLIER = "0112/2///IECCDD_001".freeze

    def self.from_row(row, schema:, meta_class_irdi:, code_property_id: nil)
      row = row.dup
      if meta_class_irdi&.code == "MDC_C0101"
        # Promote the short code to a full IRDI before parent handles it.
        # code_property_id for MDC_C0101 is the MDC code ID (MDC_P001_5).
        cid = code_property_id || Opencdd::MetaClasses.code_property_id_for("MDC_C0101")
        short = cid && row[cid]
        if short && !short.to_s.include?("#")
          row[cid] = "#{DET_CLASSIFICATION_SUPPLIER}##{short}"
        end
      end
      super
    end
  end
end
