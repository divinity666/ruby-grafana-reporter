# frozen_string_literal: true

module Grafana
  # Implements the interface to graphite datasources.
  class GraphiteDatasource < AbstractDatasource
    # @see AbstractDatasource#handles?
    def self.handles?(model)
       tmp = self.new(model)
       return tmp.type == 'graphite'
    end

    # +:raw_query+ needs to contain a Graphite query as String
    # @see AbstractDatasource#request
    def request(query_description)
      raise MissingSqlQueryError if query_description[:raw_query].nil?

      request = {
        body: URI.encode_www_form('from': DateTime.strptime(query_description[:from], '%Q').strftime('%H:%M_%Y%m%d'),
                                  'until': DateTime.strptime(query_description[:to], '%Q').strftime('%H:%M_%Y%m%d'),
                                  'format': 'json',
                                  'target': replace_variables(query_description[:raw_query], query_description[:variables])),
        content_type: 'application/x-www-form-urlencoded',
        request: Net::HTTP::Post
      }

      webrequest = query_description[:prepared_request]
      webrequest.relative_url = "/api/datasources/proxy/#{id}/render"
      webrequest.options.merge!(request)

      result = webrequest.execute(query_description[:timeout])
      preformat_response(result.body)
    end

    # @see AbstractDatasource#raw_query_from_panel_model
    def raw_query_from_panel_model(panel_query_target)
      panel_query_target['target']
    end

    private

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
