# frozen_string_literal: true

module Grafana
  class TsdbDatasource < AbstractDatasource

    def initialize(ds_model)
      @model = ds_model
    end

    def model
      @model
    end

    def url(query)
      "/api/datasources/proxy/1/render?from=#{query.from}&until=#{query.to}&format=json&target=#{query.target}"
    end

    def request(query)
      {
        request: Net::HTTP::Post
      }
    end
  end
end
