# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # This module contains common methods for all asciidoctor extensions.
    module ProcessorMixin
      # Used when initializing a object instance, to set the report object, which is currently in progress.
      # @param report [GrafanaReporter::Asciidoctor::Report] current report
      # @return [::Asciidoctor::Extensions::Processor] self
      def current_report(report)
        @report = report
        self
      end

      # This method is called if a demo report shall be built for the given {Grafana::Panel}.
      # @param panel [Grafana::Panel] panel object, for which a demo entry shall be created.
      # @return [String] String containing the entry, or nil if not possible for given panel
      def build_demo_entry(panel)
        raise NotImplementedError
      end

      # Merges the given hashes to a common attribute Hash. It respects the priorities of the hashes and the
      # object and allows only valid variables to be used.
      # @param document_hash [Hash] variables from report template level
      # @param item_hash [Hash] variables from item configuration level, i.e. specific call, which may override document
      # @return [Hash] containing accepted variable names including values
      def build_attribute_hash(document_hash, item_hash)
        result = {}

        result['grafana_report_timestamp'] = document_hash['localdatetime']
        result.merge!(document_hash.select do |k, _v|
          k =~ /^var-/ ||
          k =~ /^(?:from|to)$/ ||
          k =~ /^grafana_default_(?:from_timezone|to_timezone|timeout)$/
        end)

        result.merge!(item_hash.select do |k, _v|
          # TODO: specify accepted options for each processor class individually
          k =~ /^(?:var-|render-)/ ||
          k =~ /^(?:timeout|from|to)$/ ||
          k =~ /filter_columns|format|replace_values_.*|transpose|from_timezone|
               to_timezone|result_type|query|table_formatter|include_headline|
               column_divider|row_divider/x
        end)

        result
      end
    end
  end
end
