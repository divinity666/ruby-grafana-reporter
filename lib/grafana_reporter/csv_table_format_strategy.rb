# frozen_string_literal: true

module GrafanaReporter
  # Implements a default table format strategy, which will return tables
  # as CSV formatted strings.
  class CsvTableFormatStrategy < AbstractTableFormatStrategy
    # @see AbstractTableFormatStrategy#abbreviation
    def self.abbreviation
      'csv'
    end

    # @see AbstractTableFormatStrategy#format
    def format(result, include_headline)
      headline = result[:header].map { |item| item.to_s.gsub(',', '\\,') }.join(',')

      content = result[:content].map do |row|
        row.map { |item| item.to_s.gsub(',', '\,') }.join(',')
      end.join("\n")

      "#{headline + "\n" if include_headline}#{content}"
    end
  end
end
