# frozen_string_literal: true

require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
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
    # +format+ - see {AbstractQuery#format_columns}
    #
    # +replace_values+ - see {AbstractQuery#replace_values}
    #
    # +filter_columns+ - see {AbstractQuery#filter_columns}
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
        attrs['result_type'] = 'panel_value'
        @report.logger.debug("Processing PanelQueryValueInlineMacro (instance: #{instance}, dashboard: #{dashboard},"\
                             " panel: #{target}, query: #{attrs['query']})")

        begin
          panel = @report.grafana(instance).dashboard(dashboard).panel(target)
          query = QueryValueQuery.new(panel, variables: build_attribute_hash(parent.document.attributes, attrs))

          create_inline(parent, :quoted, query.execute)
        rescue Grafana::GrafanaError => e
          @report.logger.error(e.message)
          create_inline(parent, :quoted, e.message)
        rescue GrafanaReporterError => e
          @report.logger.error(e.message)
          create_inline(parent, :quoted, e.message)
        rescue StandardError => e
          @report.logger.fatal(e.message)
          create_inline(parent, :quoted, e.message)
        end
      end

      # @see ProcessorMixin#build_demo_entry
      def build_demo_entry(panel)
        return nil unless panel
        return nil unless panel.model['type'] == 'singlestat'

        ref_id = nil
        panel.model['targets'].each do |item|
          if !item['hide'] && !panel.query(item['refId']).to_s.empty?
            ref_id = item['refId']
            break
          end
        end
        return nil unless ref_id

        "it's easily possible to include the query value: grafana_panel_query_value:#{panel.id}[query=\"#{ref_id}\""\
        ",dashboard=\"#{panel.dashboard.id}\"] - just within this text."
      end
    end
  end
end
