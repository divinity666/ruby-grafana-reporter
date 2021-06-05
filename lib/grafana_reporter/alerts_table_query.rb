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
    end

    # Filter the query result for the given columns and sets the result in the preformatted SQL
    # result stlye.
    #
    # Additionally it applies {AbstractQuery#format_columns}, {AbstractQuery#replace_values} and
    # {AbstractQuery#filter_columns}.
    # @return [void]
    def post_process
      @result = format_columns(@result, @variables['format'])
      @result = replace_values(@result, @variables.select { |k, _v| k =~ /^replace_values_\d+/ })
      @result = filter_columns(@result, @variables['filter_columns'])

      # TODO: move formatting to Asciidoctor namespace
      @result = @result[:content].map { |row| "| #{row.map { |item| item.to_s.gsub('|', '\\|') }.join(' | ')}" }
    end
  end
end
