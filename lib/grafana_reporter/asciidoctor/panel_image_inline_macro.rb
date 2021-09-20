# frozen_string_literal: true

require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
    # Implements the hook
    #   grafana_panel_image:<panel_id>[<options>]
    #
    # Stores the queried panel as a temporary image file and returns a relative asciidoctor link
    # to the storage location, which can then be included in the report.
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
    # +instance+ - name of grafana instance, 'default' if not specified
    #
    # +dashboard+ - uid of grafana dashboard to use
    #
    # +from+ - 'from' time for the sql query
    #
    # +to+ - 'to' time for the sql query
    class PanelImageInlineMacro < ::Asciidoctor::Extensions::InlineMacroProcessor
      include ProcessorMixin
      use_dsl

      named :grafana_panel_image

      # :nodoc:
      def process(parent, target, attrs)
        return if @report.cancel

        @report.next_step
        instance = attrs['instance'] || parent.document.attr('grafana_default_instance') || 'default'
        dashboard = attrs['dashboard'] || parent.document.attr('grafana_default_dashboard')
        @report.logger.debug("Processing PanelImageInlineMacro (instance: #{instance}, dashboard: #{dashboard},"\
                             " panel: #{target})")

        begin
          # set alt text to a default, because otherwise asciidoctor fails
          attrs['alt'] = '' unless attrs['alt']
          query = PanelImageQuery.new(@report.grafana(instance).dashboard(dashboard).panel(target),
                                      variables: build_attribute_hash(parent.document.attributes, attrs))

          image = query.execute
          image_path = @report.save_image_file(image)
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

        create_inline(parent, :image, nil, { target: image_path, attributes: attrs })
      end

      # @see ProcessorMixin#build_demo_entry
      def build_demo_entry(panel)
        return nil unless panel
        return nil unless panel.model['type'] == 'graph'

        "see here: grafana_panel_image:#{panel.id}[dashboard=\"#{panel.dashboard.id}\","\
        'width="90%"] - a working inline image'
      end
    end
  end
end
