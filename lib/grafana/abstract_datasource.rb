# frozen_string_literal: true

module Grafana
  class AbstractDatasource
    def self.build_instance(ds_model)
      return SqlDatasource.new(ds_model) if ds_model['meta']['category'] == 'sql'

      case ds_model['meta']['id']
      when 'graphite'
        return GraphiteDatasource.new(ds_model)

      when 'influxdb'
        return InfluxDbDatasource.new(ds_model)

      when 'prometheus'
        return PrometheusDatasource.new(ds_model)

      end

      # TODO: raise no datasource found for id...
      SqlDatasource.new(ds_model)
    end

    def initialize(ds_model = nil)
      raise NotImplementedError
    end

    def name
      model['name']
    end

    def id
      model['id'].to_i
    end

    def category
      model['meta']['category']
    end

    def model
      raise NotImplementedError
    end

    def url(query)
      raise NotImplementedError
    end

    def request(query)
      raise NotImplementedError
    end

    def preformat_response(response_body)
      raise NotImplementedError
    end
  end
end
