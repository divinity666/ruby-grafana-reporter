require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
    module Extensions
      # Implements the hook
      #   include::grafana_alerts[<options>]
      #
      # Returns the results of alerts query as a asciidoctor table.
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
      # == Supported options
      # +columns+ - see {AlertsTableQuery#pre_process} (*mandatory*)
      #
      # +instance+ - name of grafana instance, 'default' if not specified
      #
      # +dashboard+ - uid of grafana dashboard to query for, empty string if no filter is wanted
      #
      # +panel+ - id of the panel to query for
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
      class AlertsTableIncludeProcessor < ::Asciidoctor::Extensions::IncludeProcessor
        include ProcessorMixin

        # :nodoc:
        def handles?(target)
          target.start_with? 'grafana_alerts'
        end

        # :nodoc:
        def process(doc, reader, _target, attrs)
          return if @report.cancel

          @report.next_step
          instance = attrs['instance'] || doc.attr('grafana_default_instance') || 'default'
          dashboard_id = attrs['dashboard'] || doc.attr('grafana_default_dashboard')
          panel_id = attrs['panel']
          @report.logger.debug("Processing AlertsTableIncludeProcessor (instance: #{instance}, dashboard: #{dashboard_id}, panel: #{panel_id})")

          query = if dashboard_id.to_s.empty?
                    # no dashboard shall be used, so also the panel will be omitted
                    AlertsTableQuery.new
                  elsif panel_id.to_s.empty?
                    # a dashboard is given, but no panel, so set filter for dashboard only
                    AlertsTableQuery.new(dashboard: @report.grafana(instance).dashboard(dashboard_id))
                  else
                    # dashboard and panel is given, so set filter for panel
                    AlertsTableQuery.new(panel: @report.grafana(instance).dashboard(dashboard_id).panel(panel_id))
                  end

          query.merge_hash_variables(doc.attributes, attrs)
          query.merge_variables(attrs.select { |k, _v| k =~ /(?:columns|limit|folderId|dashboardId|panelId|dahboardTag|dashboardQuery|state|query)/ }.transform_values { |item| ::Grafana::Variable.new(item) })
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