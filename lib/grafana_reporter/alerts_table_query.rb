# frozen_string_literal: true

module GrafanaReporter
  # This class is used to query alerts from grafana.
  class AlertsTableQuery < AbstractQuery
    # Check if mandatory {Grafana::Variable} +columns+ is specified in variables.
    #
    # The value of the +columns+ variable has to be a comma separated list of column titles, which
    # need to be included in the following list:
    # - limit
    # - dashboardId
    # - panelId
    # - query
    # - state
    # - folderId
    # - dashboardQuery
    # - dashboardTag
    # @return [void]
    def pre_process
      raise MissingMandatoryAttributeError, 'columns' unless @raw_query['columns']

      @datasource = Grafana::GrafanaAlertsDatasource.new(nil)
      @variables['after_fetch'] ||= Variable.new('filter_columns')
      @variables['after_calculate'] ||= Variable.new('format,replace_values,transpose')
    end

    # Filter the query result for the given columns and sets the result in the preformatted SQL
    # result stlye.
    #
    # Additionally it applies 'after_fetch' and 'after_calculate' actions.
    # @return [void]
    def post_process
      @result = apply(@result, @variables['after_fetch'], @variables)
      @result = apply(@result, @variables['after_calculate'], @variables)

      @result = format_table_output(@result,
                                    row_divider: @variables['row_divider'],
                                    column_divider: @variables['column_divider'],
                                    table_formatter: @variables['table_formatter'],
                                    include_headline: @variables['include_headline'],
                                    transpose: @variables['transpose'])
    end
  end
end
