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
    #   Currently supporting +:logger+ and +:ssl_cert+.
    def initialize(base_uri, key = nil, opts = {})
      @base_uri = base_uri
      @key = key
      @dashboards = {}
      @ssl_cert = opts[:ssl_cert]
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

    # Returns the ID of a datasource, which has been queried by the datasource name.
    #
    # @return [Integer] ID for the specified datasource name
    def datasource_id(datasource_name)
      datasource_name = 'default' unless datasource_name
      return @datasources[datasource_name] if @datasources[datasource_name]

      raise DatasourceDoesNotExistError.new('name', datasource_name)
    end

    # Returns if the given datasource ID exists for the grafana instance.
    #
    # @return [Boolean] true if exists, false otherwise
    def datasource_id_exists?(datasource_id)
      @datasources.value?(datasource_id)
    end

    # @param dashboard_uid [String] UID of the searched {Dashboard}
    # @return [Dashboard] dashboard object, if it has been found
    def dashboard(dashboard_uid)
      return @dashboards[dashboard_uid] unless @dashboards[dashboard_uid].nil?

      response = execute_http_request("/api/dashboards/uid/#{dashboard_uid}")
      model = JSON.parse(response.body)['dashboard']

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
    def execute_http_request(relative_uri, options = {}, timeout = nil)
      uri = URI.parse(@base_uri + relative_uri)
      default_options = { accept: 'application/json', request: Net::HTTP::Get, content_type: 'application/json' }
      options = default_options.merge(options)

      http = Net::HTTP.new(uri.host, uri.port)
      if @base_uri =~ /^https/
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        if @ssl_cert and not File.exist?(@ssl_cert)
          @logger.warn('SSL certificate file does not exist.')
        elsif ENV['OCRA_EXECUTABLE'] and @ssl_cert
          cert = OpenSSL::X509::Certificate.new(File.read(@ssl_cert))
          http.cert_store.add_cert(cert)
        end
      end
      http.read_timeout = timeout.to_i if timeout

      request = options[:request].new(uri.request_uri)
      request['Accept'] = options[:accept]
      request['Content-Type'] = options[:content_type]
      request['Authorization'] = "Bearer #{@key}" unless @key.nil?
      request.body = options[:body]

      @logger.debug("Requesting #{relative_uri} with '#{options[:body]}' and timeout '#{http.read_timeout}'")
      http.request(request)
    end

    private

    def initialize_datasources
      @datasources = {}

      settings = execute_http_request('/api/frontend/settings')
      return unless settings.is_a?(Net::HTTPOK)

      json = JSON.parse(settings.body)
      json['datasources'].select { |k,v| v['id'].to_i > 0 }.each do |ds_name, ds_value|
        @datasources[ds_name] = ds_value['id'].to_i
      end
      @datasources['default'] = @datasources[json['defaultDatasource']]
    end
  end
end
