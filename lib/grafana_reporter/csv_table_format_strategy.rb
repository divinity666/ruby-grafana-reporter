# frozen_string_literal: true

module GrafanaReporter
  # Implements a default table format strategy, which will return tables
  # as CSV formatted strings.
  class CsvTableFormatStrategy < AbstractTableFormatStrategy
    # @see AbstractTableFormatStrategy#abbreviation
    def self.abbreviation
      'csv'
    end

    # @see AbstractTableFormatStrategy#format_rules
    def format_rules
      {
        row_start: '',
        row_end: "\n",
        cell_start: '',
        between_cells: ', ',
        cell_end: '',
        replace_string_or_regex: ',',
        replacement: '\\,'
      }
    end
  end
end
