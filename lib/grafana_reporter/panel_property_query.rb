# frozen_string_literal: true

module GrafanaReporter
  # This class is used to query properties from a {Grafana::Panel}, such as +description+,
  # +title+ etc.
  class PanelPropertyQuery < AbstractQuery
    # @see Grafana::AbstractQuery#pre_process
    def pre_process
      @datasource = Grafana::GrafanaPropertyDatasource.new(nil)
    end

    # @see Grafana::AbstractQuery#post_process
    def post_process
      @result = @result[:content].first
    end

    # @see Grafana::AbstractQuery#raw_query
    def raw_query
      @raw_query.merge({ panel: @panel })
    end
  end
end
