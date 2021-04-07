# frozen_string_literal: true

module Grafana
  class SqlDatasource < AbstractDatasource

    def initialize(ds_model)
      @model = ds_model
    end

    def model
      @model
    end

    def url(query)
      '/api/tsdb/query'
    end

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

    # Formats the SQL results returned from grafana to an easier to use format.
    #
    # The result is being formatted as stated below:
    #
    #   {
    #     :header => [column_title_1, column_title_2],
    #     :content => [
    #                   [row_1_column_1, row_1_column_2],
    #                   [row_2_column_1, row_2_column_2]
    #                 ]
    #   }
    # @param raw_result [Hash] query result hash from grafana
    # @return [Hash] sql result formatted as stated above
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
