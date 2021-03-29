# frozen_string_literal: true

module Grafana
  class WebRequest
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
    # @param url [String] URL which shall be queried
    # @param options [Hash] options, which shall be merged to the request.
    def initialize(url, options = {})
      @uri = URI.parse(url)
      default_options = { accept: 'application/json', request: Net::HTTP::Get, content_type: 'application/json' }
      @options = default_options.merge(options)

      @http = Net::HTTP.new(@uri.host, @uri.port)
      configure_ssl if @uri.request_uri =~ /^https/
    end
    
    # Executes the HTTP request
    #
    # @param timeout [Integer] number of seconds to wait, before the http request is cancelled, defaults to 60 seconds
    # @return [Response] HTTP response object
    def execute(timeout = 60)
      @http.read_timeout = timeout.to_i
      
      request = @options[:request].new(@uri.request_uri)
      request['Accept'] = @options[:accept] if @options[:accept]
      request['Content-Type'] = @options[:content_type] if @options[:content_type]
      request['Authorization'] = @options[:authorization] if @options[:authorization]
      request.body = @options[:body]

      @http.request(request)
    end

    private

    def configure_ssl
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      if @@ssl_cert && !File.exist?(@@ssl_cert)
        # TODO: @logger.warn('SSL certificate file does not exist.')
      elsif @ssl_cert
        @http.cert_store = OpenSSL::X509::Store.new
        @http.cert_store.set_default_paths
        @http.cert_store.add_file(@@ssl_cert)
      end
    end
  end
end
