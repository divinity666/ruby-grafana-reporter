# frozen_string_literal: true

module GrafanaReporter
  # This class is used to create an image out of a {Grafana::Panel}.
  class PanelImageQuery < AbstractQuery
    # Sets the proper render variables.
    def pre_process
      # TODO: properly show error, if a (maybe a repeated template) panel can not be rendered
      # TODO: ensure that in case of timezones are specified, that they are also forwarded to the image renderer
      # rename "render-" variables
      @variables = @variables.each_with_object({}) { |(k, v), h| h[k.gsub(/^render-/, '')] = v }
      @datasource = Grafana::ImageRenderingDatasource.new(nil)
    end

    # Returns the body of the http query, which contains the raw image.
    def post_process
      @result = @result[:content].first
    end

    # @see AbstractQuery#raw_query
    def raw_query
      { panel: @panel }
    end
  end
end
