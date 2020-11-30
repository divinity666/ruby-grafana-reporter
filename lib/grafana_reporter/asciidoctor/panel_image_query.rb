# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # This class is used to create an image out of a {Grafana::Panel}.
    class PanelImageQuery < Grafana::PanelImageQuery
      include QueryMixin

      # Sets the proper render variables.
      def pre_process(grafana)
        super
        @from = translate_date(@from, @variables['grafana-report-timestamp'], false)
        @to = translate_date(@to, @variables['grafana-report-timestamp'], true)
        # rename "render-" variables
        @variables.transform_keys! { |k| k.gsub(/^render-/, '') }
      end

      # Returns the body of the http query, which contains the raw image.
      def post_process
        super
        @result = @result.body
      end
    end
  end
end
