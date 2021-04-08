# frozen_string_literal: true

module Grafana
  # Implements the interface to graphite datasources.
  class GraphiteDatasource < AbstractDatasource
    # @see AbstractDatasource#url
    def url(_query)
      "/api/datasources/proxy/#{id}/render"
    end

    # @see AbstractDatasource#request
    def request(query)
      {
        body: URI.encode_www_form(
          'from': DateTime.strptime(query.from.to_s, '%Q').strftime('%H:%M_%Y%m%d'),
          'until': DateTime.strptime(query.to.to_s, '%Q').strftime('%H:%M_%Y%m%d'),
          'format': 'json',
          'target': query.sql
        ),
        content_type: 'application/x-www-form-urlencoded',
        request: Net::HTTP::Post
      }
    end

    # @see AbstractDatasource#raw_query
    def raw_query(target)
      target['target']
    end

    # @see AbstractDatasource#preformat_response
    def preformat_response(response_body)
      # TODO: support multiple metrics as return types
      {
        header: %w[value time],
        content: JSON.parse(response_body).first['datapoints']
      }
    end
  end
end
