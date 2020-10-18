require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
    module Extensions
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
          @report.logger.debug("Processing PanelPropertyInlineMacro (instance: #{instance}, dashboard: #{dashboard}, panel: #{target}, property: #{attrs[:field]})")
          query = PanelPropertyQuery.new(@report.grafana(instance).dashboard(dashboard).panel(target), attrs[:field])
          query.merge_hash_variables(parent.document.attributes, attrs)
          @report.logger.debug("from: #{query.from}, to: #{query.to}")

          begin
            description = query.execute(@report.grafana(instance))
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
      end
    end
  end
end
