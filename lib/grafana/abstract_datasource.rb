# frozen_string_literal: true

module Grafana
  # This abstract class defines the base functionalities for the common datasource implementations.
  # Additionally it provides a factory method to build a real datasource from a given specification.
  class AbstractDatasource
    attr_reader :model

    @@subclasses = []

    # Registers the subclass as datasource.
    # @param subclass [Class] class inheriting from this abstract class
    def self.inherited(subclass)
      @@subclasses << subclass
    end

    # Overwrite this method, to specify if the current datasource implementation handles the given model.
    # This method is called by {build_instance} to determine, if the current datasource implementation
    # can handle the given grafana model. By default this method returns false.
    # @param model [Hash] grafana specification of the datasource to check
    # @return [Boolean] True if fits, false otherwise
    def self.handles?(model)
      false
    end

    # Factory method to build a datasource from a given datasource Hash description.
    # @param ds_model [Hash] grafana specification of a single datasource
    # @return [AbstractDatasource] instance of a fitting datasource implementation
    def self.build_instance(ds_model)
      raise InvalidDatasourceQueryProvidedError, ds_model unless ds_model.is_a?(Hash)

      raise InvalidDatasourceQueryProvidedError, ds_model unless ds_model['meta'].is_a?(Hash)

      @@subclasses.each do |datasource_class|
        return datasource_class.new(ds_model) if datasource_class.handles?(ds_model)
      end

      UnsupportedDatasource.new(ds_model)
    end

    def initialize(model)
      @model = model
    end

    # @return [String] category of the datasource, e.g. +tsdb+ or +sql+
    def category
      @model['meta']['category']
    end

    # @return [String] type of the datasource, e.g. +mysql+
    def type
      @model['type'] || @model['meta']['id']
    end

    # @return [String] name of the datasource
    def name
      @model['name']
    end

    # @return [String] unique ID of the datasource
    def uid
      @model['uid']
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
    # @option query_description [String] :grafana_version grafana version, for which the request is to be prepared
    # @option query_description [String] :from +from+ timestamp
    # @option query_description [String] :to +to+ timestamp
    # @option query_description [Integer] :timeout expected timeout for the request
    # @option query_description [WebRequest] :prepared_request prepared web request for relevant {Grafana} instance, if this is needed by datasource
    # @option query_description [String] :raw_query raw query, which shall be executed. May include variables, which will be replaced before execution
    # @option query_description [Hash<Variable>] :variables hash of variables, which can potentially be replaced in the given +:raw_query+
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

    # @abstract
    #
    # Overwrite in subclass, to specify the default variable format during replacement of variables.
    # @return [String] default {Variable#value_formatted} format
    def default_variable_format
      raise NotImplementedError
    end

    # Replaces the grafana variables in the given string with their replacement value.
    #
    # @param string [String] string in which the variables shall be replaced
    # @param variables [Hash<String,Variable>] Hash containing the variables, which shall be replaced in the
    #  given string
    # @param overwrite_default_format [String] {Variable#value_formatted} value, if a custom default format should be used, otherwise {#default_variable_format} is used as default, which may be overwritten
    # @return [String] string in which all variables are properly replaced
    def replace_variables(string, variables, overwrite_default_format = nil)
      res = string
      repeat = true
      repeat_count = 0

      # TODO: find a proper way to replace variables recursively instead of over and over again
      # TODO: add tests for recursive replacement of variable
      while repeat && (repeat_count < 3)
        repeat = false
        repeat_count += 1

        variables.each do |name, variable|
          # do not replace with non grafana variables
          next unless name =~ /^var-/

          # only set ticks if value is string
          var_name = name.gsub(/^var-/, '')
          next unless var_name =~ /^\w+$/

          res = res.gsub(/(?:\$\{#{var_name}(?::(?<format>\w+))?\}|\$#{var_name}(?!\w))/) do
            format = overwrite_default_format
            format = default_variable_format if overwrite_default_format.nil?
            if $LAST_MATCH_INFO
              format = $LAST_MATCH_INFO[:format] if $LAST_MATCH_INFO[:format]
            end
            variable.value_formatted(format)
          end
        end
        repeat = true if res.include?('$')
      end

      res
    end

    private

    # Provides a general method to handle the given query response as general Grafana Dataframe format.
    #
    # This method throws {UnsupportedQueryResponseReceivedError} if the given query response is not a
    # properly formattes dataframe
    #
    # @param response_body [String] raw response body
    def preformat_dataframe_response(response_body)
      json = JSON.parse(response_body)
      data = json['results'].values.first

      # TODO: check how multiple frames have to be handled
      data = data['frames']
      headers = []
      data.first['schema']['fields'].each do |headline|
        use_name_only = true
        if not headline['config'].nil?
          if not headline['config']['displayNameFromDS'].nil?
            use_name_only = false
          end
        end
        header = use_name_only ? headline['name'] : headline['config']['displayNameFromDS']
        headers << header
      end
      content = data.first['data']['values'][0].zip(data.first['data']['values'][1])
      return { header: headers, content: content }

    rescue
      raise UnsupportedQueryResponseReceivedError, response_body
    end
  end
end
