if ENV['COVERALLS_REPO_TOKEN']
  require 'coveralls'

  # FIXME monkey-patch coveralls, as this is needed for coveralls API calls from appveyor
  module Coveralls
    class API

      class << self
        alias_method :build_request_orig, :build_request
        alias_method :build_client_orig, :build_client
      end

      private

      def self.build_client(uri)
        client = self.build_client_orig(uri)
        if client.ssl_version == 'TLSv1'
          Coveralls::Output.puts("[ruby-grafana-reporter] monkey patching Coveralls::API client", :color => "yellow")
          client.ssl_version = 'TLSv1_2'
        else
          Coveralls::Output.puts("[ruby-grafana-reporter] monkey patching Coveralls::API client no longer needed and may be REMOVED", :color => "yellow")
        end
        client
      end

      def self.build_request(path, hash)
        request = self.build_request_orig(path, hash)
        if request.content_type.include?(",")
          Coveralls::Output.puts("[ruby-grafana-reporter] monkey patching Coveralls::API request", :color => "yellow")
          request.content_type = request.content_type.gsub(/,/, ";")
        else
          Coveralls::Output.puts("[ruby-grafana-reporter] monkey patching Coveralls::API request no longer needed and may be REMOVED", :color => "yellow")
        end
        request
      end
    end
  end

  Coveralls.wear! do
    add_filter "spec/"
  end
else
  require 'simplecov'
  SimpleCov.start do
    add_filter "spec/"
  end
end

require_relative '../lib/ruby_grafana_reporter'
require_relative 'ruby-grafana-reporter_spec.rb'
