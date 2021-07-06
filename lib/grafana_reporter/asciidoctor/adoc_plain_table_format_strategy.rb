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

      # @see AbstractTableFormatStrategy#format
      def format(result, include_headline)
        headline = '| ' + result[:header].map { |item| item.to_s.gsub(' | ', '\\|') }.join(' | ')

        content = result[:content].map do |row|
          '| ' + row.map { |item| item.to_s.gsub(' | ', '\\|') }.join(' | ')
        end.join("\n")

        "#{"#{headline}\n" if include_headline}#{content}"
      end
    end
  end
end
