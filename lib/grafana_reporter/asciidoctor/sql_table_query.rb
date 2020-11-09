# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # This class is being used to execute a SQL query against a grafana datasource.
    # The results will be formatted as as asciidoctor table.
    class SqlTableQuery < Grafana::AbstractSqlQuery
      include QueryMixin

      # Executes {QueryMixin#format_columns}, {QueryMixin#replace_values} and
      # {QueryMixin#filter_columns} on the query results.
      #
      # Finally the results are formatted as a asciidoctor table.
      # @return [void]
      def post_process
        results = preformat_sql_result(@result.body)
        results = format_columns(results, @variables['format'])
        results = replace_values(results, @variables.select { |k, _v| k =~ /^replace_values_\d+/ })
        results = filter_columns(results, @variables['filter_columns'])
        if @variables['filter_column']
          @report.logger.warn("DEPRECATED: Call of  no longer supported function 'filter_column' has been found."\
                              " Rename to 'filter_columns'")
          results = filter_columns(results, @variables['filter_column'])
        end
        results = transpose(results, @variables['transpose'])
        row_divider = '| '
        row_divider = @variables['row_divider'].raw_value if @variables['row_divider'].is_a?(Grafana::Variable)
        column_divider = ' | '
        column_divider = @variables['column_divider'].raw_value if @variables['column_divider'].is_a?(Grafana::Variable)

        @result = results[:content].map do |row|
          row_divider + row.map do |item|
            column_divider == ' | ' ? item.to_s.gsub('|', '\\|') : item.to_s
          end.join(column_divider)
        end
      end
    end
  end
end
