# frozen_string_literal: true

module GrafanaReporter
  # Implements a datasource to return environment related information about the reporter in a tabular format.
  class ReporterEnvironmentDatasource < ::Grafana::AbstractDatasource
    # @see AbstractDatasource#request
    def request(query_description)
      {
        header: ['Version', 'Release Date'],
        content: [[GRAFANA_REPORTER_VERSION.join('.'), GRAFANA_REPORTER_RELEASE_DATE]]
      }
    end

    # @see AbstractDatasource#default_variable_format
    def default_variable_format
      nil
    end

    # @see AbstractDatasource#name
    def name
      self.class.to_s
    end
  end
end
