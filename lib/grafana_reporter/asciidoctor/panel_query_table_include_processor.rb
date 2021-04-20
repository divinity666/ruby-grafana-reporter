# frozen_string_literal: true

require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
    # Implements the hook
    #   include::grafana_panel_query_table:<panel_id>[<options>]
    #
    # Returns the results of the SQL query as a asciidoctor table.
    #
    # == Used document parameters
    # +grafana_default_instance+ - name of grafana instance, 'default' if not specified
    #
    # +grafana_default_dashboard+ - uid of grafana default dashboard to use
    #
    # +from+ - 'from' time for the sql query
    #
    # +to+ - 'to' time for the sql query
    #
    # All other variables starting with +var-+ will be used to replace grafana templating strings
    # in the given SQL query.
    #
    # == Supported options
    # +query+ - query letter, which shall be used, e.g. +C+ (*mandatory*)
    #
    # +instance+ - name of grafana instance, 'default' if not specified
    #
    # +dashboard+ - uid of grafana dashboard to use
    #
    # +from+ - 'from' time for the sql query
    #
    # +to+ - 'to' time for the sql query
    #
    # +format+ - see {AbstractQuery#format_columns}
    #
    # +replace_values+ - see {AbstractQuery#replace_values}
    #
    # +filter_columns+ - see {AbstractQuery#filter_columns}
    class PanelQueryTableIncludeProcessor < ::Asciidoctor::Extensions::IncludeProcessor
      include ProcessorMixin

      # :nodoc:
      def handles?(target)
        target.start_with? 'grafana_panel_query_table:'
      end

      # :nodoc:
      def process(doc, reader, target, attrs)
        return if @report.cancel

        @report.next_step
        panel_id = target.split(':')[1]
        instance = attrs['instance'] || doc.attr('grafana_default_instance') || 'default'
        dashboard = attrs['dashboard'] || doc.attr('grafana_default_dashboard')
        attrs['result_type'] = 'panel_table'
        @report.logger.debug("Processing PanelQueryTableIncludeProcessor (instance: #{instance}, "\
                             "dashboard: #{dashboard}, panel: #{panel_id}, query: #{attrs['query']})")

        begin
          panel = @report.grafana(instance).dashboard(dashboard).panel(panel_id)
          query = QueryValueQuery.new(panel)
          assign_dashboard_defaults(query, panel.dashboard)
          assign_doc_and_item_variables(query, doc.attributes, attrs)
          @report.logger.debug("from: #{query.from}, to: #{query.to}")

          reader.unshift_lines query.execute
        rescue GrafanaReporterError => e
          @report.logger.error(e.message)
          reader.unshift_line "|#{e.message}"
        rescue StandardError => e
          @report.logger.fatal(e.message)
          reader.unshift_line "|#{e.message}"
        end

        reader
      end

      # @see ProcessorMixin#build_demo_entry
      def build_demo_entry(panel)
        return nil unless panel
        return nil unless panel.model['type'].include?('table')

        ref_id = nil
        panel.model['targets'].each do |item|
          if !item['hide'] && !panel.query(item['refId']).to_s.empty?
            ref_id = item['refId']
            break
          end
        end
        return nil unless ref_id

        "|===\ninclude::grafana_panel_query_table:#{panel.id}[query=\"#{ref_id}\",filter_columns=\"time\","\
        "dashboard=\"#{panel.dashboard.id}\"]\n|==="
      end
    end
  end
end
