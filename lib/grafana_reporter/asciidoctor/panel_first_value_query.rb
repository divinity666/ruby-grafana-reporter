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
        @datasource_name = @panel.field('datasource')
        @datasource = grafana.datasource_by_name(@datasource_name)
        super(grafana)
        @from = translate_date(@from, @variables['grafana-report-timestamp'], false, @variables['from_timezone'] ||
                               @variables['grafana_default_from_timezone'])
        @to = translate_date(@to, @variables['grafana-report-timestamp'], true, @variables['to_timezone'] ||
                             @variables['grafana_default_to_timezone'])
      end

      # @see AbstractQuery#self.build_demo_entry
      def self.build_demo_entry(panel)
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
