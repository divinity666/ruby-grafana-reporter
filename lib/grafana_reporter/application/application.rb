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

      def initialize
        @config = Configuration.new
      end

      # This is the main method, which is called, if the application is
      # run in standalone mode.
      # @param params [Array<String>] command line parameters, mainly ARGV can be used.
      # @return [Integer] 0 if everything is fine, -1 if execution aborted.
      def configure_and_run(params = [])
        config_file = CONFIG_FILE
        # TODO store cli_config in configuration object and merge with config file for cleaner code
        cli_config = {}
        cli_config ['grafana-reporter'] = {}
        cli_config ['default-document-attributes'] = {}

        parser = OptionParser.new do |opts|
          opts.banner = "Usage: ruby #{$PROGRAM_NAME} [options]"

          opts.on('-c', '--config CONFIG_FILE_NAME', 'Specify custom configuration file,'\
                  " instead of #{CONFIG_FILE}.") do |file_name|
            config_file = file_name
          end

          opts.on('-d', '--debug LEVEL', 'Specify detail level: FATAL, ERROR, WARN, INFO, DEBUG.') do |level|
            # TODO: add as configuration option
            if level =~ /(?:FATAL|ERROR|WARN|INFO|DEBUG)/
              config.logger.level = Object.const_get("::Logger::Severity::#{level}")
            end
          end

          opts.on('-o', '--output FILE', 'Output filename if only a single file is rendered') do |file|
            cli_config['to_file'] = file
          end

          opts.on('-s', '--set VARIABLE,VALUE', Array, 'Set a variable value, which will be passed to the rendering') do |list|
            raise ParameterValueError.new(list.length) unless list.length == 2
            cli_config['default-document-attributes'][list[0]] = list[1]
          end

          opts.on('--test GRAFANA_INSTANCE', 'test current configuration against given GRAFANA_INSTANCE') do |instance|
            cli_config['grafana-reporter']['run-mode'] = 'test'
            cli_config['grafana-reporter']['test-instance'] = instance
          end

          opts.on('-t', '--template TEMPLATE', 'Render a single ASCIIDOC template to PDF and exit') do |template|
            cli_config['grafana-reporter']['run-mode'] = 'single-render'
            cli_config['default-document-attributes']['var-template'] = template
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

        begin
          parser.parse!(params)
        rescue ApplicationError => e
          puts e.message
          return -1
        end

        # abort if config file does not exist
        unless File.exist?(config_file)
          puts "Config file '#{config_file}' does not exist. Consider calling the configuration wizard"\
               ' with option \'-w\' or use \'-h\' to see help message. Aborting.'
          return -1
        end

        # read config file
        new_config = GrafanaReporter::Configuration.new
        new_config.logger = @config.logger
        config_hash = nil
        begin
          config_hash = YAML.load_file(config_file)
        rescue StandardError => e
          raise ConfigurationError, "Could not read config file '#{config_file}' (Error: #{e.message})"
        end

        # merge command line configuration with read config file
        config_hash.merge!(cli_config) { |_key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2) : v2 }
        new_config.config = config_hash
        @config = new_config

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
            puts e.message
          end

        when Configuration::MODE_SERVICE
          Webservice.new(config).run
        end

        0
      end

      private

      # Provides a command line configuration wizard for setting up the necessary configuration
      # file.
      def config_wizard
        if File.exist?(CONFIG_FILE)
          input = nil
          until input
            input = user_input("Configuration file '#{CONFIG_FILE}' already exists. Do you want to overwrite it?", 'yN')
            return if input =~ /^(?:n|N|yN)$/
          end
        end

        puts 'This wizard will guide you through an initial configuration for'\
             ' the ruby-grafana-reporter. The configuration file will be created'\
             ' in the current folder. Please make sure to specify necessary paths'\
             ' either with a relative or an absolute path properly.'
        puts
        port = ui_config_port
        grafana = ui_config_grafana
        templates = ui_config_templates_folder
        reports = ui_config_reports_folder
        images = ui_config_images_folder(templates)
        retention = ui_config_retention

        config_yaml = %(# This configuration has been built with the configuration wizard.

#{grafana}

grafana-reporter:
  templates-folder: #{templates}
  reports-folder: #{reports}
  report-retention: #{retention}
  webservice-port: #{port}

default-document-attributes:
  imagesdir: #{images}
# feel free to add here additional asciidoctor document attributes which are applied to all your templates
)

        begin
          File.write(CONFIG_FILE, config_yaml, mode: 'w')
          puts 'Configuration file successfully created.'
        rescue StandardError => e
          raise e
        end

        config = Configuration.new
        begin
          config.config = YAML.load_file(CONFIG_FILE)
          puts 'Configuration file validated successfully.'
        rescue StandardError => e
          raise ConfigurationError, "Could not read config file '#{CONFIG_FILE}' (Error: #{e.message})\n"\
                "Source:\n#{File.read(CONFIG_FILE)}"
        end

        # create a demo report
        unless Dir.exist?(config.templates_folder)
          puts "Skip creation of DEMO template, as folder '#{config.templates_folder}' does not exist."
          return
        end
        demo_report = %(= First Grafana Report Template

include::grafana_help[]

include::grafana_environment[])

        demo_report_file = "#{config.templates_folder}demo_report.adoc"
        if File.exist?(demo_report_file)
          puts "Skip creation of DEMO template, as file '#{demo_report_file}' already exists."
        else
          begin
            File.write(demo_report_file, demo_report, mode: 'w')
            puts "DEMO template '#{demo_report_file}' successfully created."
          rescue StandardError => e
            raise e
          end
        end

        puts
        puts 'Now everything is setup properly. Run the grafana reporter without any command to start the service.'
        puts
        puts '   ruby-grafana-reporter'
        puts
        puts "Open 'http://localhost:#{config.webserver_port}/render?var-template=demo_report' in a webbrowser to"
        puts 'verify your configuration.'
      end

      def ui_config_grafana
        valid = false
        url = nil
        api_key = nil
        datasources = ''
        until valid
          url ||= user_input('Specify grafana host', 'http://localhost:3000')
          print "Testing connection to '#{url}' #{api_key ? '_with_' : '_without_'} API key..."
          begin
            res = Grafana::Grafana.new(url,
                                       api_key,
                                       logger: config.logger).test_connection
          rescue StandardError => e
            puts
            puts e.message
          end
          puts 'done.'

          case res
          when 'Admin'
            valid = true

          when 'NON-Admin'
            print 'Access to grafana is permitted as NON-Admin. Do you want to use an [a]pi key,'\
                  ' configure [d]atasource manually, [r]e-enter api key or [i]gnore? [adRi]: '

            case gets
            when /(?:i|I)$/
              valid = true

            when /(?:a|A)$/
              print 'Enter API key: '
              api_key = gets.sub(/\n$/, '')

            when /(?:r|R|adRi)$/
              api_key = nil

            when /(?:d|D)$/
              valid = true
              datasources = ui_config_datasources

            end

          else
            print "Grafana could not be accessed at '#{url}'. Do you want do [r]e-enter url, or"\
                 ' [i]gnore and proceed? [Ri]: '

            case gets
            when /(?:i|I)$/
              valid = true

            else
              url = nil
              api_key = nil

            end

          end
        end
        %(grafana:
  default:
    host: #{url}#{api_key ? "\n    api_key: #{api_key}" : ''}#{datasources ? "\n#{datasources}" : ''}
)
      end

      def ui_config_datasources
        finished = false
        datasources = []
        until finished
          item = {}
          print "Datasource ###{datasources.length + 1}) Enter datasource name as configured in grafana: "
          item[:ds_name] = gets.sub(/\n$/, '')
          print "Datasource ###{datasources.length + 1}) Enter datasource id: "
          item[:ds_id] = gets.sub(/\n$/, '')

          puts
          selection = user_input("Datasource name: '#{item[:ds_name]}', Datasource id: '#{item[:ds_id]}'."\
                                 ' [A]ccept, [r]etry or [c]ancel?', 'Arc')

          case selection
          when /(?:Arc|A|a)$/
            datasources << item
            another = user_input('Add [a]nother datasource or [d]one?', 'aD')
            finished = true if another =~ /(?:d|D)$/

          when /(?:c|C)$/
            finished = true

          end
        end
        "    datasources:\n#{datasources.collect { |el| "      #{el[:ds_name]}: #{el[:ds_id]}" }.join('\n')}"
      end

      def ui_config_port
        input = nil
        until input
          input = user_input('Specify port on which reporter shall run', '8815')
          input = nil unless input =~ /[0-9]+/
        end
        input
      end

      def ui_config_templates_folder
        input = nil
        until input
          input = user_input('Specify path where templates shall be stored', './templates')
          input = nil unless validate_config_folder(input)
        end
        input
      end

      def ui_config_reports_folder
        input = nil
        until input
          input = user_input('Specify path where created reports shall be stored', './reports')
          input = nil unless validate_config_folder(input)
        end
        input
      end

      def ui_config_images_folder(parent)
        input = nil
        until input
          input = user_input('Specify path where rendered images shall be stored (relative to templates folder)',
                             './images')
          input = nil unless validate_config_folder(File.join(parent, input))
        end
        input
      end

      def ui_config_retention
        input = nil
        until input
          input = user_input('Specify report retention duration in hours', '24')
          input = nil unless input =~ /[0-9]+/
        end
        input
      end

      def user_input(text, default)
        print "#{text} [#{default}]: "
        input = gets.gsub(/\n$/, '')
        input = default if input.empty?
        input
      end

      def validate_config_folder(folder)
        return true if Dir.exist?(folder)

        print "Directory '#{folder} does not exist: [c]reate, [r]e-enter path or [i]gnore? [cRi]: "
        case gets
        when /^(?:c|C)$/
          begin
            Dir.mkdir(folder)
            puts "Directory '#{folder}' successfully created."
            return true
          rescue StandardError => e
            puts "WARN: Directory '#{folder}' could not be created. Please create it manually."
            puts e.message
          end

        when /^(?:i|I)$/
          puts "WARN: Directory '#{folder}' does not exist. Please create manually."
          return true
        end

        false
      end
    end
  end
end
