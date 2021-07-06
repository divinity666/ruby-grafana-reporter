# frozen_string_literal: true

module GrafanaReporter
  # This class is used to query annotations from grafana.
  class AnnotationsTableQuery < AbstractQuery
    # Check if mandatory {Grafana::Variable} +columns+ is specified in variables.
    #
    # The value of the +columns+ variable has to be a comma separated list of column titles, which
    # need to be included in the following list:
    # - limit
    # - alertId
    # - userId
    # - type
    # - tags
    # - dashboardId
    # - panelId
    # @return [void]
    def pre_process
      raise MissingMandatoryAttributeError, 'columns' unless @raw_query['columns']

      @datasource = Grafana::GrafanaAnnotationsDatasource.new(nil)
    end

    # Filters the query result for the given columns and sets the result
    # in the preformatted SQL result style.
    #
    # Additionally it applies {AbstractQuery#format_columns}, {AbstractQuery#replace_values} and
    # {AbstractQuery#filter_columns}.
    # @return [void]
    def post_process
      @result = format_columns(@result, @variables['format'])
      @result = replace_values(@result, @variables.select { |k, _v| k =~ /^replace_values_\d+/ })
      @result = filter_columns(@result, @variables['filter_columns'])

      @result = format_table_output(@result,
                                    row_divider: @variables['row_divider'],
                                    column_divider: @variables['column_divider'],
                                    table_formatter: @variables['table_formatter'],
                                    include_headline: @variables['include_headline'])
    end
  end
end
