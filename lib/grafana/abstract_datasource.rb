# frozen_string_literal: true

module Grafana
  # This abstract class defines the base functionalities for the common datasource implementations.
  # Additionally it provides a factory method to build a real datasource from a given specification.
  class AbstractDatasource
    attr_reader :model

    # Factory method to build a datasource from a given datasource Hash description.
    # @param ds_model [Hash] grafana specification of a single datasource
    # @return [AbstractDatasource] instance of a fitting datasource implementation
    def self.build_instance(ds_model)
      raise InvalidDatasourceQueryProvidedError, ds_model unless ds_model.is_a?(Hash)
      raise InvalidDatasourceQueryProvidedError, ds_model unless ds_model['meta']
      raise InvalidDatasourceQueryProvidedError, ds_model unless ds_model['meta']['id']
      raise InvalidDatasourceQueryProvidedError, ds_model unless ds_model['meta']['category']

      return SqlDatasource.new(ds_model) if ds_model['meta']['category'] == 'sql'

      case ds_model['meta']['id']
      when 'graphite'
        return GraphiteDatasource.new(ds_model)

      when 'prometheus'
        return PrometheusDatasource.new(ds_model)

      end

      raise DatasourceTypeNotSupportedError.new(ds_model['name'], ds_model['meta']['id'])
    end

    def initialize(ds_model)
      @model = ds_model || {}
    end

    # @return [String] name of the datasource
    def name
      @model['name']
    end

    # @return [Integer] ID of the datasource
    def id
      @model['id'].to_i
    end

    # @return [String] grafana datasource category, e.g. +sql+ or +tsdb+
    def category
      return nil unless @model['meta']

      @model['meta']['category']
    end

    # @abstract
    #
    # Builds a proper URL to be used for the given {AbstractQuery} object. This URL will
    # then be requested with a {WebRequest}.
    #
    # @param query [AbstractQuery] query, which will be sent to this datasource object
    # @return [String] URL, which shall be requested to receive the datasource results
    def url(query)
      raise NotImplementedError
    end

    # @abstract
    #
    # Builds a proper request Hash, for the given {AbstractQuery} object. This will then
    # be passed to the {WebRequest#initialize} method as +options+ parameter.
    #
    # @param query [AbstractQuery] query, which will be sent to this datasource object
    # @return [Hash] request parameters, which will be passed to {WebRequest#initialize} as +options+
    def request(query)
      raise NotImplementedError
    end

    # @abstract
    #
    # @param target [Hash] grafana panel target, which stores the query description
    # @return [String] query string, which will be used as {AbstractSqlQuery#sql}
    def raw_query(target)
      raise NotImplementedError
    end

    # @abstract
    #
    # Used to format the query response to the following standard format:
    #
    #   {
    #     :header => [column_title_1, column_title_2],
    #     :content => [
    #                   [row_1_column_1, row_1_column_2],
    #                   [row_2_column_1, row_2_column_2]
    #                 ]
    #   }
    # @param response_body [String] returned from the database request in an unchanged format
    # @return [Hash] sql result formatted as stated above
    def preformat_response(response_body)
      raise NotImplementedError
    end
  end
end
