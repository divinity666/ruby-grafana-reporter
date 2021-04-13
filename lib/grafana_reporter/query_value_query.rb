# frozen_string_literal: true

module GrafanaReporter
  # This class provides a general query implementation for any kind of single value and table queries.
  class QueryValueQuery < AbstractQuery
    # Translates the from and to times.
    # @see Grafana::AbstractQuery#pre_process
    def pre_process
      @datasource = @panel.datasource if @panel

      @from = translate_date(@from, @variables['grafana-report-timestamp'], false, @variables['from_timezone'] ||
                             @variables['grafana_default_from_timezone'])
      @to = translate_date(@to, @variables['grafana-report-timestamp'], true, @variables['to_timezone'] ||
                           @variables['grafana_default_to_timezone'])
      @variables['result_type'] ||= Variable.new('')
    end

    # Executes {QueryMixin#format_columns}, {QueryMixin#replace_values} and
    # {QueryMixin#filter_columns} on the query results.
    #
    # Finally the results are formatted as a asciidoctor table.
    # @see Grafana::AbstractQuery#post_process
    def post_process
      modify_results

      case @variables['result_type'].raw_value
      when /(?:panel_table|sql_table)/
        result_to_table

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

    def result_to_table
      row_div = '| '
      row_div = @variables['row_divider'].raw_value if @variables['row_divider'].is_a?(Grafana::Variable)
      col_div = ' | '
      col_div = @variables['column_divider'].raw_value if @variables['column_divider'].is_a?(Grafana::Variable)

      @result = @result[:content].map do |row|
        row_div + row.map do |item|
          col_div == ' | ' ? item.to_s.gsub('|', '\\|') : item.to_s
        end.join(col_div)
      end
    end

    def modify_results
      @result = format_columns(@result, @variables['format'])
      @result = replace_values(@result, @variables.select { |k, _v| k =~ /^replace_values_\d+/ })
      @result = filter_columns(@result, @variables['filter_columns'])
      @result = transpose(@result, @variables['transpose'])
    end
  end
end
