# frozen_string_literal: true

module Grafana
  # Implements the interface to Prometheus datasources.
  class PrometheusDatasource < AbstractDatasource
    # @see AbstractDatasource#url
    def url(query)
      "/api/datasources/proxy/#{id}/api/v1/query_range?start=#{query.from}&end=#{query.to}&query=#{query.sql}"
    end

    # @see AbstractDatasource#request
    def request(_query)
      {
        request: Net::HTTP::Get
      }
    end

    # @see AbstractDatasource#raw_query
    def raw_query(target)
      target['expr']
    end

    # @see AbstractDatasource#preformat_response
    def preformat_response(response_body)
      # TODO: support multiple metrics as return types
      {
        header: %w[time value],
        content: JSON.parse(response_body)['data']['result'].first['values']
      }
    end
  end
end
