require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
    module Extensions
      # Implements the hook
      #   grafana_panel_image::<panel_id>[<options>]
      #
      # Stores the queried panel as a temporary image file and returns an asciidoctor link
      # to be included in the report.
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
      # +field+ - property to query for, e.g. +description+ or +title+ (*mandatory*)
      #
      # +instance+ - name of grafana instance, 'default' if not specified
      #
      # +dashboard+ - uid of grafana dashboard to use
      #
      # +from+ - 'from' time for the sql query
      #
      # +to+ - 'to' time for the sql query
      class PanelImageBlockMacro < ::Asciidoctor::Extensions::BlockMacroProcessor
        include ProcessorMixin
        use_dsl

        named :grafana_panel_image

        # :nodoc:
        def process(parent, target, attrs)
          return if @report.cancel

          @report.next_step
          instance = attrs['instance'] || parent.document.attr('grafana_default_instance') || 'default'
          dashboard = attrs['dashboard'] || parent.document.attr('grafana_default_dashboard')
          @report.logger.debug("Processing PanelImageBlockMacro (instance: #{instance}, dashboard: #{dashboard}, panel: #{target})")
          query = PanelImageQuery.new(@report.grafana(instance).dashboard(dashboard).panel(target))
          query.merge_hash_variables(parent.document.attributes, attrs)
          @report.logger.debug("from: #{query.from}, to: #{query.to}")

          begin
            image = query.execute(@report.grafana(instance))
            image_path = @report.save_image_file(image)
          rescue GrafanaReporterError => e
            @report.logger.error(e.message)
            return create_paragraph(parent, e.message, attrs)
          rescue StandardError => e
            @report.logger.fatal(e.message)
            return create_paragraph(parent, e.message, attrs)
          end

          attrs['target'] = image_path
          create_image_block(parent, attrs)
        end
      end
    end
  end
end
