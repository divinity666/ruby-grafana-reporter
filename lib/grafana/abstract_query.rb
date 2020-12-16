# frozen_string_literal: true

module Grafana
  # @abstract Override {#url}, #{#request}, {#pre_process} and {#post_process} in subclass.
  #
  # Superclass containing everything for all queries towards grafana.
  class AbstractQuery
    attr_accessor :from, :to, :timeout, :result
    attr_reader :variables

    def initialize
      @variables = {}
    end

    # Runs the whole process to receive values properly from this query:
    # - calls {#pre_process}
    # - executes this query against the given {Grafana} instance
    # - calls {#post_process}
    # - returns the result
    #
    # @param grafana [Grafana] {Grafana} object, against which the query is executed
    # @return [Object] result of the query
    def execute(grafana)
      return @result unless @result.nil?

      pre_process(grafana)
      @result = grafana.execute_http_request(url, request, timeout)
      post_process
      @result
    end

    # Used to retrieve default configurations from the given {Dashboard} and store them as settings in the query.
    #
    # Following data is extracted:
    # - +from+, by {Dashboard#from_time}
    # - +to+, by {Dashboard#to_time}
    # - and all variables as {Variable}, prefixed with +var-+, as grafana also does it
    def extract_dashboard_variables(dashboard)
      @from = dashboard.from_time
      @to = dashboard.to_time
      dashboard.variables.each { |item| merge_variables({ "var-#{item.name}": item }) }
      self
    end

    # Merges the given Hash with the stored variables.
    #
    # Can be used to easily set many values at once in the local variables hash.
    #
    # Please note, that the values of the Hash need to be of type {Variable}.
    #
    # @param hash [Hash<String,Variable>] Hash containing variable name as key and {Variable} as value
    # @return [AbstractQuery] this object
    def merge_variables(hash)
      hash.each do |k, v|
        if @variables[k.to_s].nil?
          @variables[k.to_s] = v
        else
          @variables[k.to_s].raw_value = v.raw_value
        end
      end
      self
    end

    # @return [Hash<String, Variable>] all grafana variables stored in this query, i.e. the variable name
    #  is prefixed with +var-+
    def grafana_variables
      @variables.select { |k, _v| k =~ /^var-.+/ }
    end

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
          res = res.gsub(/(?:\$\{#{variable}(?::(?<format>\w+))?\}|(?<!\.)\$#{variable}(?!\.))/) do
            obj.value_formatted($LAST_MATCH_INFO ? $LAST_MATCH_INFO[:format] : nil)
          end
        end
        repeat = true if res.include?('$')
      end

      res
    end

    # @abstract
    #
    # @return [String] String containing the relative URL to execute the query
    def uri
      raise NotImplementedError
    end

    # @abstract
    #
    # @return [Hash] Hash containing the request parameters, which shall be overwritten or extended in
    #  {Grafana#execute_http_request}
    def request
      raise NotImplementedError
    end

    # @abstract
    #
    # Use this function to perform all necessary actions, before the query is actually executed.
    # Here you can e.g. set values of variables or similar.
    #
    # @param grafana [Grafana] {Grafana} object, against which the query shall be executed
    def pre_process(grafana)
      raise NotImplementedError
    end

    # @abstract
    #
    # Use this function to format the raw result of the @result variable to conform to the expected return value.
    # You might also want to {#replace_variables} in the @result or similar.
    def post_process
      raise NotImplementedError
    end
  end
end
