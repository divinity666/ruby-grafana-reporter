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
      def format(result, include_headline, transposed)
        content = result[:content]
        if include_headline
          if transposed
            content.each_index do |i|
              content[i] = [result[:header][i]] + content[i]
            end
          else
            content = content.unshift(result[:header])
          end
        end

        content.map do |row|
          '| ' + row.map { |item| item.to_s.gsub(' | ', '\\|') }.join(' | ')
        end.join("\n")
      end
    end
  end
end
