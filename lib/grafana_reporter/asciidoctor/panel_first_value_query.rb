# frozen_string_literal: true

require_relative 'sql_first_value_query'

module GrafanaReporter
  module Asciidoctor
    # (see SqlFirstValueQuery)
    #
    # The SQL query as well as the datasource configuration are thereby captured from a
    # {Grafana::Panel}.
    class PanelFirstValueQuery < SqlFirstValueQuery
      include QueryMixin

      # (see PanelTableQuery#initialize)
      def initialize(panel, query_letter)
        super(nil, nil)
        @panel = panel
        @query_letter = query_letter
        extract_dashboard_variables(@panel.dashboard)
      end

      # (see PanelTableQuery#pre_process)
      def pre_process(grafana)
        @sql = @panel.query(@query_letter)
        # resolve datasource name
        @datasource = @panel.field('datasource')
        @datasource_id = grafana.datasource_id(@datasource)
        super(grafana)
        @from = translate_date(@from, @variables['grafana-report-timestamp'], false)
        @to = translate_date(@to, @variables['grafana-report-timestamp'], true)
      end
    end
  end
end
