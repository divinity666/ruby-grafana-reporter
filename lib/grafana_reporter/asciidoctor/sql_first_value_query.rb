# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # This class is being used to execute a SQL query against a grafana datasource.
    # Only the first result in the first column will be returned as a single value.
    class SqlFirstValueQuery < Grafana::AbstractSqlQuery
      include QueryMixin

      # Executes {QueryMixin#format_columns}, {QueryMixin#replace_values} and
      # {QueryMixin#filter_columns} on the query results.
      #
      # Finally only the first value in the first row and the first column of
      # will be returned.
      # @return [void]
      def post_process
        results = preformat_sql_result(@result.body)
        results = format_columns(results, @variables['format'])
        results = replace_values(results, @variables.select { |k, _v| k =~ /^replace_values_\d+/ })
        results = filter_columns(results, @variables['filter_columns'])

        @result = ''
        return if results[:content].empty?
        return if results[:content][0].empty?

        @result = results[:content][0][0]
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
        return nil unless panel.model['type'] == 'singlestat'

        refId = nil
        panel.model['targets'].each do |item|
          if !item['hide'] && !item["rawSql"].to_s.empty?
            refId = item['refId']
            break
          end
        end
        return nil unless refId

        "grafana_sql_value:#{panel.dashboard.grafana.datasource_by_name(panel.model["datasource"]).id}[sql=\"#{panel.query(refId).gsub(/"/,'\"').gsub("\n",' ').gsub(/\\/,"\\\\")}\",from=\"now-1h\",to=\"now\"]"
      end
    end
  end
end
