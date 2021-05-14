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

      # Sets default configurations from the given {Grafana::Dashboard} and store them as settings in the
      # {AbstractQuery}.
      #
      # Following data is extracted:
      # - +from+, by {Grafana::Dashboard#from_time}
      # - +to+, by {Grafana::Dashboard#to_time}
      # - and all variables as {Grafana::Variable}, prefixed with +var-+, as grafana also does it
      # @param query [AbstractQuery] query object, for which the defaults are set
      # @param dashboard [Grafana::Dashboard] dashboard from which the defaults are captured
      def assign_dashboard_defaults(query, dashboard)
        query.from = dashboard.from_time
        query.to = dashboard.to_time
        dashboard.variables.each { |item| query.assign_variable("var-#{item.name}", item) }
      end

      # Merges the given hashes to the given query object. It respects the priorities of the hashes and the
      # object and allows only valid variables to be passed.
      # @param query [AbstractQuery] query object, for which the defaults are set
      # @param document_hash [Hash] variables from report template level
      # @param item_hash [Hash] variables from item configuration level, i.e. specific call, which may override document
      # @return [void]
      def assign_doc_and_item_variables(query, document_hash, item_hash)
        sel_doc_items = document_hash.select do |k, _v|
          k =~ /^var-/ || k == 'localdatetime' || k =~ /grafana_default_(?:from|to)_timezone/
        end
        sel_doc_items.each { |k, v| query.assign_variable(k, ::Grafana::Variable.new(v)) }

        sel_items = item_hash.select do |k, _v|
          # TODO: specify accepted options in each class or check if simply all can be allowed with prefix +var-+
          k =~ /^var-/ || k =~ /^render-/ || k =~ /filter_columns|format|replace_values_.*|transpose|column_divider|
                                                   row_divider|from_timezone|to_timezone|result_type|query/x
        end
        sel_items.each { |k, v| query.assign_variable(k, ::Grafana::Variable.new(v)) }

        query.timeout = item_hash['timeout'] || document_hash['grafana-default-timeout'] || query.timeout
        query.from = item_hash['from'] || document_hash['from'] || query.from
        query.to = item_hash['to'] || document_hash['to'] || query.to
      end
    end
  end
end
