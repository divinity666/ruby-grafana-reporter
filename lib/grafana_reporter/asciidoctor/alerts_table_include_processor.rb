# frozen_string_literal: true

require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
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
    # +format+ - see {AbstractQuery#format_columns}
    #
    # +replace_values+ - see {AbstractQuery#replace_values}
    #
    # +filter_columns+ - see {AbstractQuery#filter_columns}
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
        @report.logger.debug("Processing AlertsTableIncludeProcessor (instance: #{instance},"\
                             " dashboard: #{dashboard_id}, panel: #{panel_id})")

        query = AlertsTableQuery.new(@report.grafana(instance))
        assign_dashboard_defaults(query, @report.grafana(instance).dashboard(dashboard_id)) if dashboard_id
        defaults = {}
        defaults['dashboardId'] = dashboard_id if dashboard_id
        defaults['panelId'] = panel_id if panel_id

        assign_doc_and_item_variables(query, doc.attributes, attrs)
        selected_attrs = attrs.select do |k, _v|
          k =~ /(?:columns|limit|folderId|dashboardId|panelId|dahboardTag|dashboardQuery|state|query)/x
        end
        query.raw_query = defaults.merge(selected_attrs.each_with_object({}) { |(k, v), h| h[k] = v })
        @report.logger.debug("from: #{query.from}, to: #{query.to}")

        begin
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
      def build_demo_entry(_panel)
        "|===\ninclude::grafana_alerts[columns=\"panelId,name,state\"]\n|==="
      end
    end
  end
end