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
    attr_reader :logger

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

    # @return [Hash] Information about the current organization
    def organization
      return @organization if @organization

      response = prepare_request({ relative_url: '/api/org/' }).execute
      if response.is_a?(Net::HTTPOK)
        @organization = JSON.parse(response.body)
      end

      @organization
    end

    # @return [String] grafana version
    def version
      return @version if @version

      response = prepare_request({ relative_url: '/api/health' }).execute
      if response.is_a?(Net::HTTPOK)
        @version = JSON.parse(response.body)['version']
      end

      @version
    end

    # Used to test a connection to the grafana instance.
    #
    # Running this function also determines, if the API configured here has Admin or NON-Admin privileges,
    # or even fails on connecting to grafana.
    #
    # @return [String] +Admin+, +NON-Admin+ or +Failed+ is returned, depending on the test results
    def test_connection
      if prepare_request({ relative_url: '/api/datasources' }).execute.is_a?(Net::HTTPOK)
        # we have admin rights
        @logger.warn('Reporter is running with Admin privileges on grafana. This is a potential security risk.')
        return 'Admin'
      end
      # check if we have lower rights
      return 'Failed' unless prepare_request({ relative_url: '/api/dashboards/home' }).execute.is_a?(Net::HTTPOK)

      @logger.info('Reporter is running with NON-Admin privileges on grafana.')
      'NON-Admin'
    end

    # Returns the datasource, which has been queried by model entry in the panel model.
    #
    # @param model_entry [Object] model entry of the searched datasource (e.g. String or Hash)
    # @return [Datasource] Datasource for the specified datasource model entry
    def datasource_by_model_entry(model_entry)
      datasource = nil
      if model_entry.is_a?(String)
        datasource = datasource_by_name(model_entry)
      elsif model_entry.is_a?(Hash)
        datasource = datasource_by_uid(model_entry[:uid])
      end

      raise DatasourceDoesNotExistError.new('model entry', model_entry) unless datasource

      datasource
    end

    # Returns the datasource, which has been queried by the datasource name.
    #
    # @param datasource_name [String] name of the searched datasource
    # @return [Datasource] Datasource for the specified datasource name
    def datasource_by_name(datasource_name)
      datasource_name = 'default' if datasource_name.to_s.empty?
      # TODO: PRIO add support for grafana builtin datasource types
      return UnsupportedDatasource.new(nil) if datasource_name.to_s =~ /-- (?:Mixed|Dashboard|Grafana) --/
      raise DatasourceDoesNotExistError.new('name', datasource_name) unless @datasources[datasource_name]

      @datasources[datasource_name]
    end

    # Returns the datasource, which has been queried by the datasource uid.
    #
    # @param datasource_uid [String] unique id of the searched datasource
    # @return [Datasource] Datasource for the specified datasource unique id
    def datasource_by_uid(datasource_uid)
      raise DatasourceDoesNotExistError.new('uid', datasource_uid) unless datasource_uid

      clean_nil_datasources
      datasource = @datasources.select { |ds_name, ds| ds.uid == datasource_uid }.values.first
      raise DatasourceDoesNotExistError.new('uid', datasource_uid) unless datasource

      datasource
    end

    # Returns the datasource, which has been queried by the datasource id.
    #
    # @param datasource_id [Integer] id of the searched datasource
    # @return [Datasource] Datasource for the specified datasource id
    def datasource_by_id(datasource_id)
      clean_nil_datasources
      datasource = @datasources.select { |name, ds| ds.id == datasource_id.to_i }.values.first
      raise DatasourceDoesNotExistError.new('id', datasource_id) unless datasource

      datasource
    end

    # @return [Array] Array of dashboard uids within the current grafana object
    def dashboard_ids
      response = prepare_request({ relative_url: '/api/search' }).execute
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

      response = prepare_request({ relative_url: "/api/dashboards/uid/#{dashboard_uid}" }).execute
      raise DashboardDoesNotExistError, dashboard_uid unless response.is_a?(Net::HTTPOK)

      # cache dashboard for reuse
      model = JSON.parse(response.body)['dashboard']
      @dashboards[dashboard_uid] = Dashboard.new(model, self)

      @dashboards[dashboard_uid]
    end

    # Prepares a {WebRequest} object for the current {Grafana} instance, which may be enriched
    # with further properties and can then run {WebRequest#execute}.
    #
    # @option options [Hash] :relative_url relative URL with a leading slash, which shall be queried
    # @option options [Hash] :accept
    # @option options [Hash] :body
    # @option options [Hash] :content_type
    # @return [WebRequest] webrequest prepared for execution
    def prepare_request(options = {})
      auth = @key ? { authorization: "Bearer #{@key}" } : {}
      WebRequest.new(@base_uri, auth.merge({ logger: @logger }).merge(options))
    end

    private

    def initialize_datasources
      @datasources = {}

      settings = prepare_request({ relative_url: '/api/frontend/settings' }).execute
      return unless settings.is_a?(Net::HTTPOK)

      json = JSON.parse(settings.body)
      json['datasources'].select { |_k, v| v['id'].to_i.positive? }.each do |ds_name, ds_value|
        @datasources[ds_name] = AbstractDatasource.build_instance(ds_value)

        # print debug info for https://github.com/divinity666/ruby-grafana-reporter/issues/29
        if @datasources[ds_name].nil?
          @logger.error("Datasource with name '#{ds_name}' and configuration: '#{ds_value}' could not be initialized.")
          @datasources.delete(ds_name)
        end
      end

      @datasources['default'] = @datasources[json['defaultDatasource']] if not @datasources[json['defaultDatasource']].nil?
    end

    def clean_nil_datasources
      @datasources.delete_if do |name, ds|
        if ds.nil?
          # print debug info for https://github.com/divinity666/ruby-grafana-reporter/issues/29
          @logger.warn("Datasource with name #{name} is nil, which should never happen. Check logs for details.")
        end
        ds.nil?
      end
    end
  end
end
