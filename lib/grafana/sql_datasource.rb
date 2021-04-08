# frozen_string_literal: true

module Grafana
  # Implements the interface to all SQL based datasources (tested with PostgreSQL and MariaDB/MySQL).
  class SqlDatasource < AbstractDatasource
    # @see AbstractDatasource#url
    def url(_query)
      '/api/tsdb/query'
    end

    # @see AbstractDatasource#request
    def request(query)
      {
        body: {
          from: query.from,
          to: query.to,
          queries: [rawSql: prepare_sql(query.sql), datasourceId: id, format: 'table']
        }.to_json,
        request: Net::HTTP::Post
      }
    end

    # @see AbstractDatasource#preformat_response
    def preformat_response(response_body)
      results = {}
      results.default = []

      JSON.parse(response_body)['results'].each_value do |query_result|
        if query_result.key?('error')
          results[:header] = results[:header] << ['SQL Error']
          results[:content] = [[query_result['error']]]

        elsif query_result['tables']
          query_result['tables'].each do |table|
            results[:header] = results[:header] << table['columns'].map { |header| header['text'] }
            results[:content] = table['rows']
          end

        end
      end

      results
    end

    # @see AbstractDatasource#raw_query
    def raw_query(target)
      target['rawSql']
    end

    private

    def prepare_sql(sql)
      # remove comments in query
      sql.gsub!(/--[^\r\n]*(?:[\r\n]+|$)/, ' ')
      sql.gsub!(/\r\n/, ' ')
      sql.gsub!(/\n/, ' ')
      sql
    end
  end
end
