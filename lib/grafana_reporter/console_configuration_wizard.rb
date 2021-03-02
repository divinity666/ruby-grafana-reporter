# frozen_string_literal: true

module GrafanaReporter
  class ConsoleConfigurationWizard
    # Provides a command line configuration wizard for setting up the necessary configuration
    # file.
    # TODO: refactor class
    def start_wizard(config_file, console_config)
      config = Configuration.new

      return unless overwrite_file(config_file)

      puts 'This wizard will guide you through an initial configuration for'\
           ' the ruby-grafana-reporter. The configuration file will be created'\
           ' in the current folder. Please make sure to specify necessary paths'\
           ' either with a relative or an absolute path properly.'
      puts
      puts "Wizard is creating configuration file '#{config_file}'."
      puts
      port = ui_config_port
      grafana = ui_config_grafana(console_config)
      templates = ui_config_templates_folder
      reports = ui_config_reports_folder
      images = ui_config_images_folder(templates)
      retention = ui_config_retention

      config_yaml = %(# This configuration has been built with the configuration wizard.

#{grafana}

grafana-reporter:
  report-class: GrafanaReporter::Asciidoctor::Report
  templates-folder: #{templates}
  reports-folder: #{reports}
  report-retention: #{retention}
  webservice-port: #{port}

default-document-attributes:
  imagesdir: #{images}
# feel free to add here additional asciidoctor document attributes which are applied to all your templates
)

      begin
        File.write(config_file, config_yaml, mode: 'w')
        puts 'Configuration file successfully created.'
      rescue StandardError => e
        raise e
      end

      begin
        config.config = YAML.load_file(config_file)
      rescue StandardError => e
        raise ConfigurationError, "Could not read config file '#{config_file}' (Error: #{e.message})\n"\
              "Source:\n#{File.read(config_file)}"
      end

      begin
        config.validate(true)
        puts 'Configuration file validated successfully.'
      rescue ConfigurationError => e
        raise e
      end

      demo_report = create_demo_report(config)

      demo_report ||= '<<your_report_name>>'
      config_param = config_file == Application::Application::CONFIG_FILE ? '' : " -c #{config_file}"
      program_call = "#{Gem.ruby} #{$PROGRAM_NAME}"
      program_call = ENV['OCRA_EXECUTABLE'].gsub("#{Dir.pwd}/".gsub('/', '\\'), '') if ENV['OCRA_EXECUTABLE']

      puts
      puts 'Now everything is setup properly. Create your reports as required in the templates '\
           'folder and run the reporter either standalone with e.g. the following command:'
      puts
      puts "   #{program_call}#{config_param} -t #{demo_report} -o demo_report_with_help.pdf"
      puts
      puts 'or run it as a service using the following command:'
      puts
      puts "   #{program_call}#{config_param}"
      puts
      puts "Open 'http://localhost:#{config.webserver_port}/render?var-template=#{demo_report}' in a webbrowser to"\
           ' test your configuration.'
    end

    private

    def create_demo_report(config)
      unless Dir.exist?(config.templates_folder)
        puts "Skip creation of DEMO template, as folder '#{config.templates_folder}' does not exist."
        return nil
      end

      demo_report = 'demo_report'
      demo_report_file = "#{config.templates_folder}#{demo_report}.adoc"

      # TODO: add question to overwrite file
      if File.exist?(demo_report_file)
        puts "Skip creation of DEMO template, as file '#{demo_report_file}' already exists."
        return demo_report
      end

      demo_report = %(= First Grafana Report Template

include::grafana_help[]

include::grafana_environment[])
      begin
        File.write(demo_report_file, demo_report, mode: 'w')
        puts "DEMO template '#{demo_report_file}' successfully created."
      rescue StandardError => e
        puts e.message
        return nil
      end

      demo_report
    end

    def ui_config_grafana(config)
      valid = false
      url = nil
      api_key = nil
      until valid
        url ||= user_input('Specify grafana host', 'http://localhost:3000')
        print "Testing connection to '#{url}' #{api_key ? '_with_' : '_without_'} API key..."
        begin
          # TODO: how to handle if ssl access if not working properly?
          res = Grafana::Grafana.new(url,
                                     api_key,
                                     logger: config.logger, ssl_cert: config.ssl_cert).test_connection
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
                ' [r]e-enter api key or [i]gnore? [aRi]: '

          case gets
          when /(?:i|I)$/
            valid = true

          # TODO: what is difference between 'a' and 'r'?
          when /(?:a|A)$/
            print 'Enter API key: '
            api_key = gets.sub(/\n$/, '')

          when /(?:r|R|adRi)$/
            api_key = nil

          end

        # TODO: ask to enter API key, if grafana cannot be accessed without that
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
    host: #{url}#{api_key ? "\n    api_key: #{api_key}" : ''}}
)
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

    def overwrite_file(config_file)
      return true unless File.exist?(config_file)

      input = nil
      until input
        input = user_input("Configuration file '#{config_file}' already exists. Do you want to overwrite it?", 'yN')
        return false if input =~ /^(?:n|N|yN)$/
      end

      true
    end
  end
end
