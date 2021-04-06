# frozen_string_literal: true

# Contains all objects for creating structured objects for interfacing grafana.
#
# The intention is, that these represent the business logic contained within grafana
# in an appropriate object model for the reporter to work with.
#
# For details, see also {https://grafana.com/docs/grafana/latest/http_api Grafana API}.
module Grafana
  # Main class for handling the interaction with one specific Grafana instance.
  class Grafana
    # @param base_uri [String] full URI pointing to the specific grafana instance without
    #   trailing slash, e.g. +https://localhost:3000+.
    # @param key [String] API key for the grafana instance, if required
    # @param opts [Hash] additional options.
    #   Currently supporting +:logger+.
    def initialize(base_uri, key = nil, opts = {})
      @base_uri = base_uri
      @key = key
      @dashboards = {}
      @logger = opts[:logger] || ::Logger.new(nil)

      initialize_datasources unless @base_uri.empty?
    end

    # Used to test a connection to the grafana instance.
    #
    # Running this function also determines, if the API configured here has Admin or NON-Admin privileges,
    # or even fails on connecting to grafana.
    #
    # @return [String] +Admin+, +NON-Admin+ or +Failed+ is returned, depending on the test results
    def test_connection
      if execute_http_request('/api/datasources').is_a?(Net::HTTPOK)
        # we have admin rights
        @logger.warn('Reporter is running with Admin privileges on grafana. This is a potential security risk.')
        return 'Admin'
      end
      # check if we have lower rights
      return 'Failed' unless execute_http_request('/api/dashboards/home').is_a?(Net::HTTPOK)

      @logger.info('Reporter is running with NON-Admin privileges on grafana.')
      'NON-Admin'
    end

    # Returns the datasource, which has been queried by the datasource name.
    #
    # @return [Datasource] Datasource for the specified datasource name
    def datasource_by_name(datasource_name)
      datasource_name ||= 'default'
      raise DatasourceDoesNotExistError.new('name', datasource_name) unless @datasources[datasource_name]

      @datasources[datasource_name]
    end

    # Returns the datasource, which has been queried by the datasource id.
    #
    # @return [Datasource] Datasource for the specified datasource id
    def datasource_by_id(datasource_id)
      datasource = @datasources.select { |_name, ds| ds.id == datasource_id }.values.first
      raise DatasourceDoesNotExistError.new('id', datasource_id) unless datasource

      datasource
    end

    # @return [Array] Array of dashboard uids within the current grafana object
    def dashboard_ids
      response = execute_http_request("/api/search")
      return [] unless response.is_a?(Net::HTTPOK)

      dashboards = JSON.parse(response.body)

      dashboards.each do |dashboard|
        @dashboards[dashboard['uid']] = nil unless @dashboards[dashboard['uid']]
      end

      @dashboards.keys
    end

    # @param dashboard_uid [String] UID of the searched {Dashboard}
    # @return [Dashboard] dashboard object, if it has been found
    def dashboard(dashboard_uid)
      return @dashboards[dashboard_uid] unless @dashboards[dashboard_uid].nil?

      response = execute_http_request("/api/dashboards/uid/#{dashboard_uid}")
      model = nil
      begin
        model = JSON.parse(response.body)['dashboard']
      rescue
      end

      raise DashboardDoesNotExistError, dashboard_uid if model.nil?

      # cache dashboard for reuse
      @dashboards[dashboard_uid] = Dashboard.new(model, self)

      @dashboards[dashboard_uid]
    end

    # Runs a specific HTTP request against the current grafana instance.
    #
    # Default (can be overridden, by specifying the options Hash):
    #   accept: 'application/json'
    #   request: Net::HTTP::Get
    #   content_type: 'application/json'
    #
    # @param relative_uri [String] relative URL with a leading slash, which shall be queried
    # @param options [Hash] options, which shall be merged to the request.
    # @param timeout [Integer] number of seconds to wait, before the http request is cancelled, defaults to 60 seconds
    def execute_http_request(relative_uri, options = {}, timeout = 60)
      auth = {}
      auth = {authorization: "Bearer #{@key}"} if @key
      WebRequest.new("#{@base_uri}#{relative_uri}", auth.merge({logger: @logger}).merge(options)).execute(timeout)
    end

    private

    def initialize_datasources
      @datasources = {}

      settings = execute_http_request('/api/frontend/settings')
      return unless settings.is_a?(Net::HTTPOK)

      json = JSON.parse(settings.body)
      json['datasources'].select { |_k, v| v['id'].to_i.positive? }.each do |ds_name, ds_value|
        begin
          @datasources[ds_name] = AbstractDatasource.build_instance(ds_value)
        rescue DatasourceTypeNotSupportedError => e
          # an unsupported datasource type has been configured in the dashboard
          # - no worries here
          @logger.warn(e.message)
        end
      end
      @datasources['default'] = @datasources[json['defaultDatasource']]
    end
  end
end
