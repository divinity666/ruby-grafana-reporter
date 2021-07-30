# frozen_string_literal: true

require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
    # Implements the hook
    #   grafana_panel_property:<panel_id>[<options>]
    #
    # Returns the requested panel property.
    #
    # == Used document parameters
    # +grafana_default_instance+ - name of grafana instance, 'default' if not specified
    #
    # +grafana_default_dashboard+ - uid of grafana default dashboard to use
    #
    # == Supported options
    # +field+ - property to query for, e.g. +description+ or +title+ (*mandatory*)
    #
    # +instance+ - name of grafana instance, 'default' if not specified
    #
    # +dashboard+ - uid of grafana dashboard to use
    class PanelPropertyInlineMacro < ::Asciidoctor::Extensions::InlineMacroProcessor
      include ProcessorMixin
      use_dsl

      named :grafana_panel_property
      name_positional_attributes :field

      # :nodoc:
      def process(parent, target, attrs)
        return if @report.cancel

        @report.next_step
        instance = attrs['instance'] || parent.document.attr('grafana_default_instance') || 'default'
        dashboard = attrs['dashboard'] || parent.document.attr('grafana_default_dashboard')
        @report.logger.debug("Processing PanelPropertyInlineMacro (instance: #{instance}, dashboard: #{dashboard},"\
                             " panel: #{target}, property: #{attrs[:field]})")

        begin
          query = PanelPropertyQuery.new(@report.grafana(instance).dashboard(dashboard).panel(target),
                                         variables: build_attribute_hash(parent.document.attributes, attrs))
          query.raw_query = { property_name: attrs[:field] }

          description = query.execute
        rescue Grafana::GrafanaError => e
          @report.logger.error(e.message)
          return create_inline(parent, :quoted, e.message)
        rescue GrafanaReporterError => e
          @report.logger.error(e.message)
          return create_inline(parent, :quoted, e.message)
        rescue StandardError => e
          @report.logger.fatal(e.message)
          return create_inline(parent, :quoted, e.message)
        end

        # translate linebreaks to asciidoctor syntax
        # and HTML encode to make sure, that HTML formattings are respected
        create_inline(parent, :quoted, CGI.escapeHTML(description.gsub(%r{//[^\n]*(?:\n)?}, '').gsub(/\n/, " +\n")))
      end

      # @see ProcessorMixin#build_demo_entry
      def build_demo_entry(panel)
        return nil unless panel
        return nil unless panel.model['title']
        return nil if panel.model['title'].strip == ''
        return nil if panel.model['title'].strip == 'Panel Title'

        "this text includes the panel with title grafana_panel_property:#{panel.id}[\"title\","\
        "dashboard=\"#{panel.dashboard.id}\"]"
      end
    end
  end
end
