# frozen_string_literal: true

module Grafana
  # Implements the interface to Prometheus datasources.
  class InfluxDbDatasource < AbstractDatasource
    # @see AbstractDatasource#handles?
    def self.handles?(model)
      tmp = new(model)
      tmp.type == 'influxdb'
    end

    # +:database+ needs to contain the InfluxDb database name
    # +:raw_query+ needs to contain a InfluxDb query as String
    # @see AbstractDatasource#request
    def request(query_description)
      raise MissingSqlQueryError if query_description[:raw_query].nil?

      url = "/api/datasources/proxy/#{id}/query?db=#{@model['database']}&q=#{URI.encode(query_description[:raw_query])}&epoch=ms"

      webrequest = query_description[:prepared_request]
      webrequest.relative_url = url
      webrequest.options.merge!({ request: Net::HTTP::Get })

      result = webrequest.execute(query_description[:timeout])
      preformat_response(result.body)
    end

    # @see AbstractDatasource#raw_query_from_panel_model
    def raw_query_from_panel_model(panel_query_target)
      return panel_query_target['query'] if panel_query_target['rawQuery']

      # TODO: support composed queries
      raise ComposedQueryNotSupportedError, self
    end

    private

    # @see AbstractDatasource#preformat_response
    def preformat_response(response_body)
      results = {}
      results.default = []

      # TODO: support multiple responses as influx query result
      json = JSON.parse(response_body)
      query_result = json['results'].first['series'].first

      query_result['columns'].each do |header|
        results[:header] = results[:header] << header
      end
      results[:content] = query_result['values']

      results
    end
  end
end
