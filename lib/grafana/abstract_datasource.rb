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

      UnsupportedDatasource.new(ds_model)
    end

    def initialize(model)
      @model = model
    end

    # @return [String] name of the datasource
    def name
      @model['name']
    end

    # @return [Integer] ID of the datasource
    def id
      @model['id'].to_i
    end

    # @abstract
    #
    # Executes a request for the current database with the given options.
    #
    # Used format of the response will always be the following:
    #
    #   {
    #     :header => [column_title_1, column_title_2],
    #     :content => [
    #                   [row_1_column_1, row_1_column_2],
    #                   [row_2_column_1, row_2_column_2]
    #                 ]
    #   }
    #
    # @param query_description [Hash] query description, which will requested:
    # @option [String] :from +from+ timestamp
    # @option [String] :to +to+ timestamp
    # @option [Integer] :timeout expected timeout for the request
    # @option [WebRequest] :prepared_request prepared web request for relevant {Grafana} instance, if this is needed by datasource
    # @option [String] :raw_query raw query, which shall be executed. May include variables, which will be replaced before execution
    # @option [Hash<Variable>] :variables hash of variables, which can potentially be replaced in the given +:raw_query+
    # @return [Hash] sql result formatted as stated above
    def request(query_description)
      raise NotImplementedError
    end

    # @abstract
    #
    # The different datasources supported by grafana use different ways to store the query in the
    # panel's JSON model. This method extracts a query from that description, that can be used
    # by the {AbstractDatasource} implementation of the datasource.
    #
    # @param panel_query_target [Hash] grafana panel target, which contains the query description
    # @return [String] query string, which can be used as +raw_query+ in a {#request}
    def raw_query_from_panel_model(panel_query_target)
      raise NotImplementedError
    end

    private

    # Replaces the grafana variables in the given string with their replacement value.
    #
    # @param string [String] string in which the variables shall be replaced
    # @param variables [Hash<String,Variable>] Hash containing the variables, which shall be replaced in the
    #  given string
    # @return [String] string in which all variables are properly replaced
    def replace_variables(string, variables = {})
      res = string
      repeat = true
      repeat_count = 0

      # TODO: find a proper way to replace variables recursively instead of over and over again
      # TODO: add tests for recursive replacement of variable
      while repeat && (repeat_count < 3)
        repeat = false
        repeat_count += 1
        variables.each do |var_name, obj|
          # only set ticks if value is string
          variable = var_name.gsub(/^var-/, '')
          res = res.gsub(/(?:\$\{#{variable}(?::(?<format>\w+))?\}|\$#{variable})/) do
            # TODO: respect datasource requirements for formatting here
            obj.value_formatted($LAST_MATCH_INFO ? $LAST_MATCH_INFO[:format] : nil)
          end
        end
        repeat = true if res.include?('$')
      end

      res
    end
  end
end
