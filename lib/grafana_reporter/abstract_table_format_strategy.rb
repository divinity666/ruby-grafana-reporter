# frozen_string_literal: true

module GrafanaReporter
  # The abstract base class, which is to be implemented for different table
  # output formats. By implementing this class, you e.g. can decide if a table
  # will be formatted as CSV, JSON or any other format.
  class AbstractTableFormatStrategy
    @@subclasses = []

    def self.inherited(obj)
      @@subclasses << obj
    end

    # @param abbreviation [String] name of the requested table format strategy
    # @return [AbstractTableFormatStrategy] fitting strategy instance for the given name
    def self.get(abbreviation)
      @@subclasses.select { |item| item.abbreviation == abbreviation }.first.new
    end

    # @abstract
    # @return [String] short name of the current stategy, under which it shall be accessible
    def self.abbreviation
      raise NotImplementedError
    end

    # Used to format a given content array to the desired output format. The default
    # implementation applies the {#format_rules} to create a custom string export. If
    # this is not sufficient for a desired table format, you may simply overwrite this
    # function to have full freedom about the desired output.
    # @param content [Hash] datasource table result
    # @param include_headline [Boolean] true, if headline should be included in result
    # @param transposed [Boolean] true, if result array is in transposed format
    # @return [String] formatted in table format
    def format(content, include_headline, transposed)
      result = content[:content]

      # add the headline at the correct position to the content array
      if include_headline
        if transposed
          result.each_index do |i|
            result[i] = [content[:header][i]] + result[i]
          end
        else
          result = result.unshift(content[:header])
        end
      end

      # translate the content to a table
      result.map do |row|
        format_rules[:row_start] + row.map do |item|
          value = item.to_s
          if format_rules[:replace_string_or_regex]
            value = value.gsub(format_rules[:replace_string_or_regex], format_rules[:replacement])
          end

          format_rules[:cell_start] + value + format_rules[:cell_end]
        end.join(format_rules[:between_cells])
      end.join(format_rules[:row_end])
    end

    # Formatting rules, which are applied to build the table output format.
    def format_rules
      {
        row_start: '',
        row_end: '',
        cell_start: '',
        between_cells: '',
        cell_end: '',
        replace_string_or_regex: nil,
        replacement: ''
      }
    end
  end
end
