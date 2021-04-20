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
      # Default file name for grafana reporter configuration file
      CONFIG_FILE = 'grafana_reporter.config'

      # Contains the {Configuration} object of the application.
      attr_accessor :config

      # Stores the {Webservice} object of the application
      attr_reader :webservice

      def initialize
        @config = Configuration.new
        @webservice = Webservice.new
      end

      # This is the main method, which is called, if the application is
      # run in standalone mode.
      # @param params [Array<String>] command line parameters, mainly ARGV can be used.
      # @return [Integer] 0 if everything is fine, -1 if execution aborted.
      def configure_and_run(params = [])
        config_file = CONFIG_FILE
        tmp_config = Configuration.new
        action_wizard = false

        parser = OptionParser.new do |opts|
          opts.banner = if ENV['OCRA_EXECUTABLE']
                          "Usage: #{ENV['OCRA_EXECUTABLE'].gsub("#{Dir.pwd}/".gsub('/', '\\'), '')} [options]"
                        else
                          "Usage: #{Gem.ruby} #{$PROGRAM_NAME} [options]"
                        end

          opts.on('-c', '--config CONFIG_FILE_NAME', 'Specify custom configuration file,'\
                  " instead of #{CONFIG_FILE}.") do |file_name|
            config_file = file_name
          end

          opts.on('-d', '--debug LEVEL', 'Specify detail level: FATAL, ERROR, WARN, INFO, DEBUG.') do |level|
            tmp_config.set_param('grafana-reporter:debug-level', level)
          end

          opts.on('-o', '--output FILE', 'Output filename if only a single file is rendered') do |file|
            tmp_config.set_param('to_file', file)
          end

          opts.on('-s', '--set VARIABLE,VALUE', Array, 'Set a variable value, which will be passed to the '\
                  'rendering') do |list|
            raise ParameterValueError, list.length unless list.length == 2

            tmp_config.set_param("default-document-attributes:#{list[0]}", list[1])
          end

          opts.on('--ssl-cert FILE', 'Manually specify a SSL cert file for HTTPS connection to grafana. Only '\
                  'needed if not working properly otherwise.') do |file|
            if File.file?(file)
              tmp_config.set_param('grafana-reporter:ssl-cert', file)
            else
              config.logger.warn("SSL certificate file #{file} does not exist. Setting will be ignored.")
            end
          end

          opts.on('--test GRAFANA_INSTANCE', 'test current configuration against given GRAFANA_INSTANCE') do |instance|
            tmp_config.set_param('grafana-reporter:run-mode', 'test')
            tmp_config.set_param('grafana-reporter:test-instance', instance)
          end

          opts.on('-t', '--template TEMPLATE', 'Render a single ASCIIDOC template to PDF and exit') do |template|
            tmp_config.set_param('grafana-reporter:run-mode', 'single-render')
            tmp_config.set_param('default-document-attributes:var-template', template)
          end

          opts.on('-w', '--wizard', 'Configuration wizard to prepare environment for the reporter.') do
            action_wizard = true
          end

          opts.on('-v', '--version', 'Version information') do
            puts GRAFANA_REPORTER_VERSION.join('.')
            return -1
          end

          opts.on('-h', '--help', 'Show this message') do
            puts opts
            return -1
          end
        end

        begin
          parser.parse!(params)
          return ConsoleConfigurationWizard.new.start_wizard(config_file, tmp_config) if action_wizard
        rescue ApplicationError => e
          puts e.message
          return -1
        end

        # abort if config file does not exist
        unless File.file?(config_file)
          puts "Config file '#{config_file}' does not exist. Consider calling the configuration wizard"\
               ' with option \'-w\' or use \'-h\' to see help message. Aborting.'
          return -1
        end

        # read config file
        config_hash = nil
        begin
          config_hash = YAML.load_file(config_file)
        rescue StandardError => e
          raise ConfigurationError, "Could not read config file '#{config_file}' (Error: #{e.message})"
        end

        # merge command line configuration with read config file
        @config.config = config_hash
        @config.merge!(tmp_config)

        run
      end

      # Runs the application with the current set {Configuration} object.
      # @return [Integer] value smaller than 0, if error. 0 if successfull
      def run
        begin
          config.validate
        rescue ConfigurationError => e
          puts e.message
          return -2
        end

        case config.mode
        when Configuration::MODE_CONNECTION_TEST
          res = Grafana::Grafana.new(config.grafana_host(config.test_instance),
                                     config.grafana_api_key(config.test_instance),
                                     logger: config.logger).test_connection
          puts res

        when Configuration::MODE_SINGLE_RENDER
          begin
            config.report_class.new(config, config.template, config.to_file).create_report
          rescue StandardError => e
            puts "#{e.message}\n#{e.backtrace.join("\n")}"
          end

        when Configuration::MODE_SERVICE
          @webservice.run(config)
        end

        0
      end
    end
  end
end
