# frozen_string_literal: true

module Grafana
  class PrometheusDatasource < AbstractDatasource

    def initialize(ds_model)
      @model = ds_model
    end

    def model
      @model
    end

    def url(query)
      "/api/datasources/proxy/#{id}/api/v1/query_range?start=#{query.from}&end=#{query.to}&query=#{query.sql}"
    end

    def request(query)
      {
        request: Net::HTTP::Post
      }
    end
  end
end
