# frozen_string_literal: true

module GrafanaReporter
  # This module contains all classes, which are used by the grafana reporter
  # application. The application is a set of classes, which allows to run the
  # reporter in several ways.
  #
  # If you intend to use the reporter functionality, without the application,
  # it might be helpful to not use the classes from here.
  module Application
    # This class contains the main application to run the grafana reporter.
    #
    # It can be run to test the grafana connection, render a single template
    # or run as a service.
    class Application
      def initialize
        @logger = ::Logger.new($stderr, level: :unknown)
      end

      # Can be used to set a {Configuration} object to the application.
      #
      # This is mainly helpful in testing the application or in an
      # integrated use.
      # @param config {Configuration} configuration to be used by the application
      # @return [void]
      def config=(config)
        @logger = config.logger || @logger
        @config = config
      end

      # This is the main method, which is called, if the application is
      # run in standalone mode.
      # @param params [Array] normally the ARGV command line parameters
      # @return [Integer] see {#run}
      def configure_and_run(params = [])
        config = GrafanaReporter::Configuration.new
        config.logger.level = ::Logger::Severity::INFO
        result = config.configure_by_command_line(params)
        return result if result != 0

        self.config = config
        run
      end

      # Runs the application with the current set {Configuration} object.
      # @return [Integer] value smaller than 0, if error. 0 if successfull
      def run
        begin
          @config.validate
        rescue ConfigurationError => e
          puts e.message
          return -2
        end

        case @config.mode
        when Configuration::MODE_CONNECTION_TEST
          res = Grafana::Grafana.new(@config.grafana_host(@config.test_instance),
                                     @config.grafana_api_key(@config.test_instance),
                                     logger: @logger).test_connection
          puts res

        when Configuration::MODE_SINGLE_RENDER
          @config.report_class.new(@config, @config.template, @config.to_file).create_report

        when Configuration::MODE_SERVICE
          Webservice.new(@config).run
        end
        0
      end

    end
  end
end
