# frozen_string_literal: true

module Grafana
  # A top level alarm for all other errors in current module.
  class GrafanaError < StandardError
    def initialize(message)
      super("GrafanaError: #{message} (#{self.class})")
    end
  end

  # Raised if a given dashboard does not exist in a specific {Grafana} instance.
  class DashboardDoesNotExistError < GrafanaError
    # @param dashboard_uid [String] dashboard uid, which could not be found
    def initialize(dashboard_uid)
      super("The specified dashboard '#{dashboard_uid}' does not exist.")
    end
  end

  # Raised if a given panel does not exist on a specific {Dashboard} in the current {Grafana} instance.
  class PanelDoesNotExistError < GrafanaError
    # @param panel_id [String] panel id, which could not be found on the dashboard
    # @param dashboard [Dashboard] dashboard object on which the panel could not be found
    def initialize(panel_id, dashboard)
      super("The specified panel id '#{panel_id}' does not exist on the dashboard '#{dashboard.id}'.")
    end
  end

  # Raised if a given query letter does not exist on a specific {Panel}.
  class QueryLetterDoesNotExistError < GrafanaError
    # @param query_letter [String] query letter name, which could not be found on the panel
    # @param panel [Panel] panel object on which the query could not be found
    def initialize(query_letter, panel)
      super("The specified query '#{query_letter}' does not exist in the panel '#{panel.id}' "\
        "in dashboard '#{panel.dashboard}'.")
    end
  end

  # Raised if a given datasource does not exist in a specific {Grafana} instance.
  class DatasourceDoesNotExistError < GrafanaError
    # @param field [String] specifies, how the datasource has been searched, e.g. 'id' or 'name'
    # @param datasource_identifier [String] identifier of the datasource, which could not be found,
    #   e.g. the specifiy id or name
    def initialize(field, datasource_identifier)
      super("Datasource with #{field} '#{datasource_identifier}' does not exist.")
    end
  end

  # Raised if a {Panel} could not be rendered as an image.
  #
  # Most likely this happens, because the image renderer is not configures properly in grafana,
  # or the panel rendering ran into a timeout.
  # @param panel [Panel] panel object, which could not be rendered
  class ImageCouldNotBeRenderedError < GrafanaError
    def initialize(panel)
      super("The specified panel '#{panel.id}' from dashboard '#{panel.dashboard.id} could not be "\
        'rendered to an image.')
    end
  end

  # Raised if no SQL query is specified.
  class MissingSqlQueryError < GrafanaError
    def initialize
      super('No SQL statement has been specified.')
    end
  end

  # Raised if a datasource shall be queried, which is not (yet) supported by the reporter
  class InvalidDatasourceQueryProvidedError < GrafanaError
    def initialize(query)
      super("The datasource query provided, does not look like a grafana datasource target (received: #{query}).")
    end
  end
end
