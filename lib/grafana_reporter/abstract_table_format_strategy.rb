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

    # @abstract
    # @param column [Array] datasource table result
    # @param include_headline [Boolean] true, if headline should be included in result
    # @return [String] formatted in table format
    def format(content, include_headline)
      raise NotImplementedError
    end
  end
end
