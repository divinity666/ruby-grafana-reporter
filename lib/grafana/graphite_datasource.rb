# frozen_string_literal: true

module Grafana
  class GraphiteDatasource < AbstractDatasource

    def initialize(ds_model)
      @model = ds_model
    end

    def model
      @model
    end

    def url(query)
      "/api/datasources/proxy/#{id}/render"
    end

    def request(query)
      {
        body: URI.encode_www_form({
            'from': DateTime.strptime(query.from.to_s,'%Q').strftime('%H:%M_%Y%m%d'),
            'until': DateTime.strptime(query.to.to_s,'%Q').strftime('%H:%M_%Y%m%d'),
            'format': 'json',
            'target': query.sql
        }),
        content_type: 'application/x-www-form-urlencoded',
        request: Net::HTTP::Post
      }
    end

    def preformat_response(response_body)
      {
        header: ['value','time'],
        content: JSON.parse(response_body).first['datapoints']
      }
    end
  end
end
