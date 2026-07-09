# frozen_string_literal: true

module Cdd
  module Parcel
    # Verifies that scrape output produced populated .xls files, not
    # just schema stubs. Catches the silent failure mode discovered
    # on 2026-07-08: iec61360/iec63213/iec61360-7 scrapes appeared
    # complete (10,338 PROPERTY .xls files for iec61360) but every
    # file had 0 data rows. The build pipeline exported 574 classes
    # + 0 properties, and the browser showed "No declared properties"
    # for every class. Nothing failed loudly.
    #
    # This verifier reads every export_*.xls under a directory and
    # reports which ones are empty. Use via `rake verify_scrape[dict]`
    # or directly:
    #
    #   results = Cdd::Parcel::ScrapeVerifier.verify("downloads/iec61360")
    #   empty = results.select(&:empty?)
    #   abort "#{empty.size} empty files" unless empty.empty?
    class ScrapeVerifier
      Result = Struct.new(:path, :entity_type, :data_row_count, :status,
                          keyword_init: true) do
        def ok?    = status == :ok
        def empty? = status == :empty
      end

      FILE_PATTERN = /\Aexport_(CLASS|PROPERTY|RELATION|UNIT|VALUELIST|VALUETERMS)_[^\.]+\.(xls|xlsx)\z/i

      class << self
        def verify(directory)
          new(directory).verify
        end
      end

      attr_reader :directory

      def initialize(directory)
        @directory = directory
      end

      def verify
        xls_files.map { |f| check_file(f) }
      end

      # Summary counts — useful for CLI output.
      def summary
        results = verify
        {
          total:    results.size,
          ok:       results.count(&:ok?),
          empty:    results.count(&:empty?),
          by_type:  results.group_by(&:entity_type).transform_values(&:size),
          empty_by_type: results.select(&:empty?).group_by(&:entity_type).transform_values(&:size),
        }
      end

      # A "data row" in the Parcel wire format is a row with content
      # in column 1+ whose first cell isn't a `#` directive or comment.
      # Column 0 may be empty (the IEC CDD .xls layout leaves it blank;
      # data starts in column 1). Public so tests can verify the rule
      # without send.
      def data_row?(row)
        return false unless row.is_a?(Array) && row.size > 1
        first = row.first.to_s.strip
        return false if first.start_with?("#")
        row[1..].any? { |c| !c.nil? && !c.to_s.strip.empty? }
      end

      private

      def xls_files
        return [] unless File.directory?(@directory)
        Dir.glob(File.join(@directory, "**", "export_*.{xls,xlsx}")).sort
      end

      def check_file(path)
        rows = read_rows(path)
        data = rows.count { |r| data_row?(r) }
        Result.new(
          path: path,
          entity_type: type_from_filename(path),
          data_row_count: data,
          status: data.positive? ? :ok : :empty,
        )
      end

      def read_rows(path)
        ext = File.extname(path).downcase
        if ext == ".xls"
          read_xls_rows(path)
        else
          read_xlsx_rows(path)
        end
      rescue StandardError
        # Corrupt or unreadable files count as empty for verification
        # purposes — the user can investigate via the path.
        []
      end

      def read_xls_rows(path)
        require "spreadsheet"
        book = Spreadsheet.open(path)
        sheet = book.worksheet(0) || book.worksheets.first
        return [] unless sheet
        sheet.rows.map { |row| row.to_a }
      end

      def read_xlsx_rows(path)
        require "roo"
        roo = Roo::Spreadsheet.open(path, extension: :xlsx)
        target = roo.sheets.first || "Export"
        sheet = roo.sheet(target)
        (1..sheet.last_row.to_i).map { |i| sheet.row(i).to_a }
      end

      def type_from_filename(path)
        match = File.basename(path).match(FILE_PATTERN)
        match ? match[1] : "UNKNOWN"
      end
    end
  end
end
