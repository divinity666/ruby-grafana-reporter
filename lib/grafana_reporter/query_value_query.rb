# frozen_string_literal: true

module GrafanaReporter
  # This class provides a general query implementation for any kind of single value and table queries.
  class QueryValueQuery < AbstractQuery
    # @see Grafana::AbstractQuery#pre_process
    def pre_process
      if @panel
        @panel.resolve_variable_datasource(@variables)
        @datasource = @panel.datasource
      end

      @variables['result_type'] ||= ::Grafana::Variable.new('')
      @variables['after_fetch'] ||= ::Grafana::Variable.new('filter_columns')
      @variables['after_calculate'] ||= ::Grafana::Variable.new('format,replace_values,transpose')
    end

    # Executes 'after_fetch', 'after_calculate' and 'select_value' on the on the query results.
    #
    # Finally the results are formatted as a asciidoctor table.
    # @see Grafana::AbstractQuery#post_process
    def post_process
      @result = apply(@result, @variables['after_fetch'], @variables)

      case @variables['result_type'].raw_value
      when 'object'
        @result = apply(@result, @variables['after_calculate'], @variables)

      when /(?:panel_table|sql_table)/
        @result = apply(@result, @variables['after_calculate'], @variables)
        @result = format_table_output(@result, row_divider: @variables['row_divider'],
                                               column_divider: @variables['column_divider'],
                                               table_formatter: @variables['table_formatter'],
                                               include_headline: @variables['include_headline'],
                                               transpose: @variables['transpose'])

      when /(?:panel_value|sql_value)/
        tmp = @result[:content] || [[]]
        # use only first column of return values and replace null values with zero
        tmp = tmp.map{ |item| item[0] || 0 }

        # as default behaviour we fallback to the first_value, as this was the default in older releases
        select_value = 'first'
        select_value = @variables['select_value'].raw_value if @variables['select_value']
        case select_value
        when 'min'
          result = tmp.min
        when 'max'
          result = tmp.max
        when 'avg'
          result = tmp.size > 0 ? tmp.sum / tmp.size : 0
        when 'sum'
          result = tmp.sum
        when 'last'
          result = tmp.last
        when 'first'
          result = tmp.first
        else
          raise UnsupportedSelectValueStatementError, @variables['select_value'].raw_value
        end

        @result[:content] = [[result]]
        @result = apply(@result, @variables['after_calculate'], @variables)
        @result = @result[:content].flatten.first

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
  end
end
