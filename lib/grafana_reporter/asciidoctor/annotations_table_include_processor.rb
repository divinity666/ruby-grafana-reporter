# frozen_string_literal: true

require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
    # Implements the hook
    #   include::grafana_annotations[<options>]
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
    # +columns+ - see {AnnotationsTableQuery#pre_process} (*mandatory*)
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
    class AnnotationsTableIncludeProcessor < ::Asciidoctor::Extensions::IncludeProcessor
      include ProcessorMixin

      # :nodoc:
      def handles?(target)
        target.start_with? 'grafana_annotations'
      end

      # :nodoc:
      def process(doc, reader, _target, attrs)
        return if @report.cancel

        @report.next_step
        instance = attrs['instance'] || doc.attr('grafana_default_instance') || 'default'
        dashboard_id = attrs['dashboard'] || doc.attr('grafana_default_dashboard')
        panel_id = attrs['panel']
        @report.logger.debug("Processing AnnotationsTableIncludeProcessor (instance: #{instance})")

        grafana_obj = @report.grafana(instance)
        grafana_obj = @report.grafana(instance).dashboard(dashboard_id) if dashboard_id
        grafana_obj = grafana_obj.panel(panel_id) if panel_id

        query = AnnotationsTableQuery.new(grafana_obj, variables: { 'table_formatter' => 'adoc_plain' }.merge(build_attribute_hash(doc.attributes, attrs)))
        defaults = {}
        defaults['dashboardId'] = dashboard_id if dashboard_id
        defaults['panelId'] = panel_id if panel_id

        selected_attrs = attrs.select do |k, _v|
          k =~ /(?:columns|limit|alertId|dashboardId|panelId|userId|type|tags)/
        end
        query.raw_query = defaults.merge(selected_attrs.each_with_object({}) { |(k, v), h| h[k] = v })

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
        "|===\ninclude::grafana_annotations[columns=\"time,panelId,newState,prevState,text\"]\n|==="
      end
    end
  end
end
