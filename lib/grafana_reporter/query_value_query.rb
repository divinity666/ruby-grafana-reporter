# frozen_string_literal: true

module GrafanaReporter
  # This class provides a general query implementation for any kind of single value and table queries.
  class QueryValueQuery < AbstractQuery
    # @see Grafana::AbstractQuery#pre_process
    def pre_process
      @datasource = @panel.datasource if @panel

      @variables['result_type'] ||= Variable.new('')
    end

    # Executes {AbstractQuery#format_columns}, {AbstractQuery#replace_values} and
    # {AbstractQuery#filter_columns} on the query results.
    #
    # Finally the results are formatted as a asciidoctor table.
    # @see Grafana::AbstractQuery#post_process
    def post_process
      modify_results

      case @variables['result_type'].raw_value
      when 'object'

      when /(?:panel_table|sql_table)/
        @result = format_table_output(@result, row_divider: @variables['row_divider'],
                                               column_divider: @variables['column_divider'],
                                               table_formatter: @variables['table_formatter'],
                                               include_headline: @variables['include_headline'],
                                               transpose: @variables['transpose'])

      when /(?:panel_value|sql_value)/
        tmp = @result[:content] || []
        @result = tmp.flatten.first

      else
        raise StandardError, "Unsupported 'result_type' received: '#{@variables['result_type'].raw_value}'"

      end
    end

    # @see Grafana::AbstractQuery#raw_query
    def raw_query
      return @raw_query if @raw_query

      case @variables['result_type'].raw_value
      when /(?:panel_table|panel_value)/
        @variables['query'] ? @panel.query(@variables['query'].raw_value) : @panel.query(nil)

      when /(?:sql_table|sql_value)/
        nil

      else
        raise StandardError, "Unsupported 'result_type' received: '#{@variables['result_type'].raw_value}'"

      end
    end

    private

    def modify_results
      @result = format_columns(@result, @variables['format'])
      @result = replace_values(@result, @variables.select { |k, _v| k =~ /^replace_values_\d+/ })
      @result = filter_columns(@result, @variables['filter_columns'])
      @result = transpose(@result, @variables['transpose'])
    end
  end
end
