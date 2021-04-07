# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # This class is being used to execute a SQL query against a grafana datasource.
    # The results will be formatted as as asciidoctor table.
    class SqlTableQuery < Grafana::AbstractSqlQuery
      include QueryMixin

      # Executes {QueryMixin#format_columns}, {QueryMixin#replace_values} and
      # {QueryMixin#filter_columns} on the query results.
      #
      # Finally the results are formatted as a asciidoctor table.
      # @return [void]
      def post_process
        results = @datasource.preformat_response(@result.body)
        results = format_columns(results, @variables['format'])
        results = replace_values(results, @variables.select { |k, _v| k =~ /^replace_values_\d+/ })
        results = filter_columns(results, @variables['filter_columns'])
        results = transpose(results, @variables['transpose'])
        row_div = @variables['row_divider'].is_a?(Grafana::Variable) ? @variables['row_divider'].raw_value : '| '
        col_div = @variables['column_divider'].is_a?(Grafana::Variable) ? @variables['column_divider'].raw_value : ' | '

        @result = results[:content].map do |row|
          row_div + row.map do |item|
            col_div == ' | ' ? item.to_s.gsub('|', '\\|') : item.to_s
          end.join(col_div)
        end
      end

      # Translates the from and to times.
      # @see Grafana::AbstractSqlQuery#pre_process
      # @param grafana [Grafana::Grafana] grafana instance against which the query shall be executed
      # @return [void]
      def pre_process(grafana)
        super(grafana)
        @from = translate_date(@from, @variables['grafana-report-timestamp'], false, @variables['from_timezone'] ||
                               @variables['grafana_default_from_timezone'])
        @to = translate_date(@to, @variables['grafana-report-timestamp'], true, @variables['to_timezone'] ||
                             @variables['grafana_default_to_timezone'])
      end

      # (see AbstractQuery#self.build_demo_entry)
      def self.build_demo_entry(panel)
        return nil unless panel
        return nil unless panel.model['type'].include?('table')

        refId = nil
        panel.model['targets'].each do |item|
          if !item['hide'] && !panel.query(item["refId"]).to_s.empty?
            refId = item['refId']
            break
          end
        end
        return nil unless refId

        "|===\ninclude::grafana_sql_table:#{panel.dashboard.grafana.datasource_by_name(panel.model["datasource"]).id}[sql=\"#{panel.query(refId).gsub(/"/,'\"').gsub("\n",' ').gsub(/\\/,"\\\\")}\",filter_columns=\"time\",dashboard=\"#{panel.dashboard.id}\",from=\"now-1h\",to=\"now\"]\n|==="
      end
    end
  end
end
