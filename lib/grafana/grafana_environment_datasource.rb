# frozen_string_literal: true

module Grafana
  # Implements a datasource to return environment related information about the grafana instance in a tabular format.
  class GrafanaEnvironmentDatasource < ::Grafana::AbstractDatasource
    # +:raw_query+ needs to contain a Hash with the following structure:
    #
    #   {
    #     grafana:  {Grafana} object to query
    #     mode:     'general' (default) or 'dashboards' for receiving different environment information
    #   }
    # @see AbstractDatasource#request
    def request(query_description)
      raise MissingSqlQueryError if query_description[:raw_query].nil?
      raw_query = {mode: 'general'}.merge(query_description[:raw_query])

      return dashboards_data(raw_query[:grafana]) if raw_query[:mode] == 'dashboards'

      general_data(raw_query[:grafana])
    end

    # @see AbstractDatasource#default_variable_format
    def default_variable_format
      nil
    end

    # @see AbstractDatasource#name
    def name
      self.class.to_s
    end

    private

    def general_data(grafana)
      {
        header: ['Version', 'Organization Name', 'Organization ID', 'Access permissions'],
        content: [[grafana.version,
                   grafana.organization['name'],
                   grafana.organization['id'],
                   grafana.test_connection]]
      }
    end

    def dashboards_data(grafana)
      content = []
      grafana.dashboard_ids.each do |id|
        content << [id, grafana.dashboard(id).title, grafana.dashboard(id).panels.length]
      end

      {
        header: ['Dashboard ID', 'Dashboard Name', '# Panels'],
        content: content
      }
    end
  end
end
