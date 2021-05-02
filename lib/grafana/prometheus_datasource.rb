# frozen_string_literal: true

module Grafana
  # Implements the interface to Prometheus datasources.
  class PrometheusDatasource < AbstractDatasource
    # @see AbstractDatasource#handles?
    def self.handles?(model)
      tmp = self.new(model)
      return tmp.type == 'prometheus'
    end

    # +:raw_query+ needs to contain a Prometheus query as String
    # @see AbstractDatasource#request
    def request(query_description)
      raise MissingSqlQueryError if query_description[:raw_query].nil?

      url = "/api/datasources/proxy/#{id}/api/v1/query_range?"\
            "start=#{query_description[:from]}&end=#{query_description[:to]}"\
            "&query=#{replace_variables(query_description[:raw_query], query_description[:variables])}"

      webrequest = query_description[:prepared_request]
      webrequest.relative_url = url
      webrequest.options.merge!({ request: Net::HTTP::Get })

      result = webrequest.execute(query_description[:timeout])
      preformat_response(result.body)
    end

    # @see AbstractDatasource#raw_query_from_panel_model
    def raw_query_from_panel_model(panel_query_target)
      panel_query_target['expr']
    end

    private

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
