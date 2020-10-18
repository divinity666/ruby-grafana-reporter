require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
    module Extensions
      # Implements the hook
      #   grafana_panel_query_value:<panel_id>[<options>]
      #
      # Returns the first value of the resulting SQL query.
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
      class PanelQueryValueInlineMacro < ::Asciidoctor::Extensions::InlineMacroProcessor
        include ProcessorMixin
        use_dsl

        named :grafana_panel_query_value

        # :nodoc:
        def process(parent, target, attrs)
          return if @report.cancel

          @report.next_step
          instance = attrs['instance'] || parent.document.attr('grafana_default_instance') || 'default'
          dashboard = attrs['dashboard'] || parent.document.attr('grafana_default_dashboard')
          @report.logger.debug("Processing PanelQueryValueInlineMacro (instance: #{instance}, dashboard: #{dashboard}, panel: #{target}, query: #{attrs['query']})")
          query = PanelFirstValueQuery.new(@report.grafana(instance).dashboard(dashboard).panel(target), attrs['query'])
          query.merge_hash_variables(parent.document.attributes, attrs)
          @report.logger.debug("from: #{query.from}, to: #{query.to}")

          begin
            create_inline(parent, :quoted, query.execute(@report.grafana(instance)))
          rescue GrafanaReporterError => e
            @report.logger.error(e.message)
            create_inline(parent, :quoted, e.message)
          rescue StandardError => e
            @report.logger.fatal(e.message)
            create_inline(parent, :quoted, e.message)
          end
        end
      end
    end
  end
end
