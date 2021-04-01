# frozen_string_literal: true

module Grafana
  class AbstractDatasource
    def self.build_instance(ds_model)
      case ds_model['meta']['category']
      when 'sql'
        return SqlDatasource.new(ds_model)

      when 'tsdb'
        return TsdbDatasource.new(ds_model)

      end

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

  end
end
