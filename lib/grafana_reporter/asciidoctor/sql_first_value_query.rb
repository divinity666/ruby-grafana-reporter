module GrafanaReporter
  module Asciidoctor
    # This class is being used to execute a SQL query against a grafana datasource.
    # Only the first result in the first column will be returned as a single value.
    class SqlFirstValueQuery < Grafana::AbstractSqlQuery
      include QueryMixin

      # Executes {QueryMixin#format_columns}, {QueryMixin#replace_values} and
      # {QueryMixin#filter_columns} on the query results.
      #
      # Finally only the first value in the first row and the first column of
      # will be returned.
      # @return [void]
      def post_process
        results = preformat_sql_result(@result.body)
        results = format_columns(results, @variables['format'])
        results = replace_values(results, @variables.select { |k, _v| k =~ /^replace_values_\d+/ })
        results = filter_columns(results, @variables['filter_columns'])
        if @variables['filter_column']
          @report.logger.warn("DEPRECATED: Call of  no longer supported function 'filter_column' has been found. Rename to 'filter_columns'")
          results = filter_columns(results, @variables['filter_column'])
        end

        unless results[:content].empty?
          unless results[:content][0].empty?
            @result = results[:content][0][0]
            return
          end
        end
        @result = ''
      end
    end
  end
end
