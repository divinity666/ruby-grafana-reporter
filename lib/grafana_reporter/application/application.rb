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
        @logger = ::Logger.new($stdout, level: :unknown)
      end

      # Contains the {Configuration} object of the application.
      attr_accessor :config

      # This is the main method, which is called, if the application is
      # run in standalone mode.
      # @param params [Array<String>] command line parameters, mainly ARGV can be used.
      # @return [Integer] 0 if everything is fine, -1 if execution aborted.
      def configure_and_run(params = [])
        @config = GrafanaReporter::Configuration.new
        config.logger = @logger

        params << '--help' if params.empty?

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: ruby #{$PROGRAM_NAME} CONFIG_FILE [options]"

          opts.on('-d', '--debug LEVEL', 'Specify detail level: FATAL, ERROR, WARN, INFO, DEBUG.') do |level|
            if level =~ /(?:FATAL|ERROR|WARN|INFO|DEBUG)/
              config.logger.level = Object.const_get("::Logger::Severity::#{level}")
            end
          end

          opts.on('--test GRAFANA_INSTANCE', 'test current configuration against given GRAFANA_INSTANCE') do |instance|
            if config.config['grafana-reporter']
              config.config['grafana-reporter']['run-mode'] = 'test'
            else
              config.config.merge!({ 'grafana-reporter' => { 'run-mode' => 'test' } })
            end
            config.config['grafana-reporter']['test-instance'] = instance
          end

          opts.on('-t', '--template TEMPLATE', 'Render a single ASCIIDOC template to PDF and exit') do |template|
            if config.config['grafana-reporter']
              config.config['grafana-reporter']['run-mode'] = 'single-render'
            else
              config.config.merge!({ 'grafana-reporter' => { 'run-mode' => 'single-render' } })
            end
            if config.config['default-document-attributes']
              config.config['default-document-attributes']['var-template'] = template
            else
              config.config.merge!({ 'default-document-attributes' => { 'var-template' => template } })
            end
          end

          opts.on('-o', '--output FILE', 'Output filename if only a single file is rendered') do |file|
            config.config.merge!({ 'to_file' => file })
          end

          opts.on('-w', '--wizard', 'Configuration wizard to prepare environment for the reporter.') do
            return config_wizard
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

        unless params.empty?
          if File.exist?(params[0])
            config_file = params.slice!(0)
            begin
              config.config = YAML.load_file(config_file)
            rescue StandardError => e
              raise ConfigurationError, "Could not read CONFIG_FILE '#{config_file}' (Error: #{e.message})"
            end
          end
        end
        parser.parse!(params)

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
          config.report_class.new(config, config.template, config.to_file).create_report

        when Configuration::MODE_SERVICE
          Webservice.new(config).run
        end

        0
      end

      # Provides a command line configuration wizard for setting up the necessary configuration
      # file.
      def config_wizard
        if File.exist?('grafana_reporter.config')
          overwrite = user_input('Configuration file \'grafana_reporter.config\' already exists. Do you want to overwrite it?', 'yN', 'config')
          return unless overwrite
        end

        puts 'This wizard will guide you through an initial configuration for'\
             ' the ruby-grafana-reporter. The configuration file will be created'\
             ' in the current folder. Please make sure to specify necessary paths'\
             ' either with a relative or an absolute path properly.'
        puts
        port = user_input('Specify port on which reporter shall run', '8815', 'unsigned_num')
        grafana = user_input('Specify grafana host', 'http://localhost:3000', 'grafana')
        templates = user_input('Specify path where templates shall be stored', './templates', 'folder')
        reports = user_input('Specify path where created reports shall be stored', './reports', 'folder')
        images = user_input('Specify path where rendered images shall be stored (relative to reports folder)', './images', 'folder')
        retention = user_input('Specify report retention duration', '24', 'unsigned_num')

        config_yaml = %{# This configuration has been built with the configuration wizard.

grafana:
  default:
    host: #{grafana}

grafana-reporter:
  templates-folder: #{templates}
  reports-folder: #{reports}
  report-retention: #{retention}
  webservice-port: #{port}

default-document-attributes:
  imagesdir: #{images}
}

        begin
          File.write('grafana_reporter.config', config_yaml, mode: 'w')
          puts "Configuration file successfully created."
        rescue => e
          raise e
        end

        config = Configuration.new
        begin
          config.config = YAML.load_file('grafana_reporter.config')
          puts "Configuration file validated successfully."
        rescue StandardError => e
          raise ConfigurationError, "Could not read CONFIG_FILE '#{config_file}' (Error: #{e.message})"
        end
      end

      private

      def user_input(text, default, validation_type = '')
        valid = false
        until valid
          print "#{text} [#{default}]: "
          input = gets.gsub(/\n$/, '')
          input = default if input.empty?

          valid = false
          case validation_type
          when 'folder'
            return input if Dir.exist?(input)

            print "Directory '#{input} does not exist. Shall I create it? [Yn]: "
            case gets
            when /^(?:y|Y|)$/
              begin
                Dir.mkdir(input)
                puts "Directory '#{input}' successfully created."
                valid = true
              rescue => e
                puts "WARN: Directory '#{input}' does not exist. Please create manually."
                puts e.message
              end

            when /^(?:n|N)$/
              puts "WARN: Directory '#{input}' does not exist. Please create manually."
              valid = true
            end

          when 'unsigned_num'
            valid = true if input =~ /[0-9]+/

          when 'config'
            case input
            when /^(?:y|Y)$/
              input = true
              valid = true
            when /^(?:n|N|yN)$/
              input = false
              valid = true
            end

          when 'grafana'
            valid = true

          else
            valid = true
          end
        end

        puts
        input
      end
    end
  end
end
