# frozen_string_literal: true

module Grafana
  # This class standardizes all webcalls. Key functionality is to properly support HTTPS calls as a base functionality.
  class WebRequest
    attr_accessor :relative_url, :options

    @ssl_cert = nil

    class << self
      attr_accessor :ssl_cert
    end

    # Initializes a specific HTTP request.
    #
    # Default (can be overridden, by specifying the options Hash):
    #   accept: 'application/json'
    #   request: Net::HTTP::Get
    #   content_type: 'application/json'
    #
    # @param base_url [String] URL which shall be queried
    # @param options [Hash] options, which shall be merged to the request. Also allows `+logger+` option
    def initialize(base_url, options = {})
      @base_url = base_url
      default_options = { accept: 'application/json', request: Net::HTTP::Get, content_type: 'application/json' }
      @options = default_options.merge(options.reject { |k, _v| k == :logger && k == :relative_url })
      @relative_url = options[:relative_url]
      @logger = options[:logger] || Logger.new(nil)
    end

    # Executes the HTTP request
    #
    # @param timeout [Integer] number of seconds to wait, before the http request is cancelled, defaults to 60 seconds
    # @return [Response] HTTP response object
    def execute(timeout = nil)
      timeout ||= 60

      uri = URI.parse("#{@base_url}#{@relative_url}")
      @http = Net::HTTP.new(uri.host, uri.port)
      configure_ssl if @base_url =~ /^https/

      @http.read_timeout = timeout.to_i

      request = @options[:request].new(uri.request_uri)
      request['Accept'] = @options[:accept] if @options[:accept]
      request['Content-Type'] = @options[:content_type] if @options[:content_type]
      request['Authorization'] = @options[:authorization] if @options[:authorization]
      request.body = @options[:body]

      @logger.debug("Requesting #{uri} with '#{@options[:body]}' and timeout '#{timeout}'")
      response = @http.request(request)
      @logger.debug("Received response #{response}")
      @logger.debug("HTTP response body: #{response.body}") unless response.code =~ /^2.*/

      response
    end

    private

    def configure_ssl
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      if self.class.ssl_cert && !File.file?(self.class.ssl_cert)
        @logger.warn('SSL certificate file does not exist.')
      elsif self.class.ssl_cert
        @http.cert_store = OpenSSL::X509::Store.new
        @http.cert_store.set_default_paths
        @http.cert_store.add_file(self.class.ssl_cert)
      end
    end
  end
end
