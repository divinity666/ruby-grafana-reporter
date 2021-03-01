# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # This class is used to create an image out of a {Grafana::Panel}.
    class PanelImageQuery < Grafana::PanelImageQuery
      include QueryMixin

      # Sets the proper render variables.
      def pre_process(grafana)
        super
        @from = translate_date(@from, @variables['grafana-report-timestamp'], false, @variables['from_timezone'] ||
                               @variables['grafana_default_from_timezone'])
        @to = translate_date(@to, @variables['grafana-report-timestamp'], true, @variables['to_timezone'] ||
                             @variables['grafana_default_to_timezone'])
        # TODO: ensure that in case of timezones are specified, that they are also forwarded to the image renderer
        # rename "render-" variables
        @variables = @variables.each_with_object({}) { |(k, v), h| h[k.gsub(/^render-/, '')] = v }
      end

      # Returns the body of the http query, which contains the raw image.
      def post_process
        super
        @result = @result.body
      end
    end
  end
end
