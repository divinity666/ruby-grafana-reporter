# frozen_string_literal: true

module Grafana
  # Implements the interface to all SQL based datasources (tested with PostgreSQL and MariaDB/MySQL).
  class SqlDatasource < AbstractDatasource
    # @see AbstractDatasource#handles?
    def self.handles?(model)
      tmp = new(model)
      tmp.category == 'sql'
    end

    # +:raw_query+ needs to contain a SQL query as String in the respective database dialect
    # @see AbstractDatasource#request
    def request(query_description)
      raise MissingSqlQueryError if query_description[:raw_query].nil?

      sql = replace_variables(query_description[:raw_query], query_description[:variables])
      request = {
        body: {
          from: query_description[:from],
          to: query_description[:to],
          queries: [rawSql: sql, datasourceId: id, format: 'table']
        }.to_json,
        request: Net::HTTP::Post
      }

      webrequest = query_description[:prepared_request]
      webrequest.relative_url = '/api/tsdb/query'
      webrequest.options.merge!(request)

      result = webrequest.execute(query_description[:timeout])
      preformat_response(result.body)
    end

    # Currently all composed SQL queries are saved in the dashboard as rawSql, so no conversion
    # necessary here.
    # @see AbstractDatasource#raw_query_from_panel_model
    def raw_query_from_panel_model(panel_query_target)
      panel_query_target['rawSql']
    end

    # @see AbstractDatasource#default_variable_format
    def default_variable_format
        'glob'
    end

    private

    def preformat_response(response_body)
      results = {}
      results.default = []
      results[:header] = []
      results[:content] = []

      JSON.parse(response_body)['results'].each_value do |query_result|
        if query_result.key?('error')
          results[:header] = results[:header] + ['SQL Error']
          results[:content] = [[query_result['error']]]

        elsif query_result['tables']
          query_result['tables'].each do |table|
            results[:header] = results[:header] + table['columns'].map { |header| header['text'] }
            results[:content] = table['rows']
          end

        end
      end

      results
    end
  end
end
