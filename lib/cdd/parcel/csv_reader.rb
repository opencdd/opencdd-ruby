# frozen_string_literal: true

require "csv"

module Cdd
  module Parcel
    module CsvReader
      DEFAULT_ENCODING = "UTF-8".freeze

      def self.read(path, meta_class_irdi:, name: nil, col_sep: ",", encoding: DEFAULT_ENCODING)
        rows = ::CSV.read(path, col_sep: col_sep, encoding: encoding)
        rows = rows.reject { |r| r.nil? || r.all? { |c| c.nil? || c.to_s.strip.empty? } }
        meta_code = extract_meta_code(meta_class_irdi)
        scaffold = Cdd::Parcel::Sheet.scaffold(
          meta_class_irdi: meta_code,
          parcel_id: "IMPORT",
        )
        raw_rows = rows.map { |r| [nil, *r] }
        Cdd::Parcel::Sheet.new(
          name: name || File.basename(path.to_s, ".*"),
          metadata: scaffold.metadata,
          schema: scaffold.schema,
          raw_rows: raw_rows,
        )
      end

      def self.extract_meta_code(value)
        return value if value.nil?
        s = value.to_s
        s.include?("#") ? s.split("#").last : s
      end
      private_class_method :extract_meta_code
    end
  end
end
