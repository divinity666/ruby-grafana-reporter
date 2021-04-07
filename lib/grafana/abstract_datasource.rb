# frozen_string_literal: true

module Grafana
  class AbstractDatasource
    def self.build_instance(ds_model)
      raise InvalidDatasourceQueryProvidedError, ds_model unless ds_model.is_a?(Hash)
      raise InvalidDatasourceQueryProvidedError, ds_model unless ds_model['meta']
      raise InvalidDatasourceQueryProvidedError, ds_model unless ds_model['meta']['id']
      raise InvalidDatasourceQueryProvidedError, ds_model unless ds_model['meta']['category']

      return SqlDatasource.new(ds_model) if ds_model['meta']['category'] == 'sql'

      case ds_model['meta']['id']
      when 'graphite'
        return GraphiteDatasource.new(ds_model)

      # TODO: support influxdb as well
      #when 'influxdb'
        #return InfluxDbDatasource.new(ds_model)

      when 'prometheus'
        return PrometheusDatasource.new(ds_model)

      end

      raise DatasourceTypeNotSupportedError.new(ds_model['name'], ds_model['meta']['id'])
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

    def raw_query(target)
      raise NotImplementedError
    end

    def preformat_response(response_body)
      raise NotImplementedError
    end
  end
end
