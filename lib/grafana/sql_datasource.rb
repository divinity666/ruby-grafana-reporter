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
          queries: [rawSql: query.sql, datasourceId: id, format: 'table']
        }.to_json,
        request: Net::HTTP::Post
      }
    end
  end
end
