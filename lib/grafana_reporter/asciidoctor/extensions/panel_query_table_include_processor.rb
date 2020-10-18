require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
    module Extensions
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
      # +format+ - see {QueryMixin#format_columns}
      #
      # +replace_values+ - see {QueryMixin#replace_values}
      #
      # +filter_columns+ - see {QueryMixin#filter_columns}
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
          @report.logger.debug("Processing PanelQueryTableIncludeProcessor (instance: #{instance}, dashboard: #{dashboard}, panel: #{panel_id}, query: #{attrs['query']})")
          query = PanelTableQuery.new(@report.grafana(instance).dashboard(dashboard).panel(panel_id), attrs['query'])
          query.merge_hash_variables(doc.attributes, attrs)
          @report.logger.debug("from: #{query.from}, to: #{query.to}")

          begin
            reader.unshift_lines query.execute(@report.grafana(instance))
          rescue GrafanaReporterError => e
            @report.logger.error(e.message)
            reader.unshift_line '|' + e.message
          rescue StandardError => e
            @report.logger.fatal(e.message)
            reader.unshift_line '|' + e.message
          end

          reader
        end
      end
    end
  end
end
