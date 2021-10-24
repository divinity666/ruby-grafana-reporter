# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # Implements a default table format strategy, which will return tables
    # as asciidoctor formatted table.
    class AdocPlainTableFormatStrategy < AbstractTableFormatStrategy
      # @see AbstractTableFormatStrategy#abbreviation
      def self.abbreviation
        'adoc_plain'
      end

      # @see AbstractTableFormatStrategy#format_rules
      def format_rules
        {
          row_start: '| ',
          row_end: "\n",
          cell_start: '',
          between_cells: ' | ',
          cell_end: '',
          replace_string_or_regex: '|',
          replacement: '\\|'
        }
      end
    end
  end
end
