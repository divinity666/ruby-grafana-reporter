# frozen_string_literal: true

module GrafanaReporter
  # This class provides a console configuration wizard, to reduce the manual efforts that have
  # to be spent for that action and to reduce mistakes as good as possible.
  class ConsoleConfigurationWizard
    # Provides a command line configuration wizard for setting up the necessary configuration
    # file.
    def start_wizard(config_file, console_config)
      action = overwrite_or_use_config_file(config_file)
      return if action == 'abort'

      config = create_config_wizard(config_file, console_config) if action == 'overwrite'
      config ||= Configuration.new

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
      config_param = config_file == Configuration::DEFAULT_CONFIG_FILE_NAME ? '' : " -c #{config_file}"
      program_call = "#{Gem.ruby} #{$PROGRAM_NAME}"
      program_call = ENV['OCRAN_EXECUTABLE'].gsub("#{Dir.pwd}/".gsub('/', '\\'), '') if ENV['OCRAN_EXECUTABLE']

      puts
      puts 'Now everything is setup properly. Create your reports as required in the templates '\
           'folder and run the reporter either standalone with e.g. the following command:'
      puts
      puts "   #{program_call}#{config_param} -t #{demo_report} -o demo_report.#{config.report_class.default_result_extension}"
      puts
      puts 'or run it as a service using the following command:'
      puts
      puts "   #{program_call}#{config_param}"
      puts
      puts "Open 'http://localhost:#{config.webserver_port}/render?var-template=#{demo_report}' in a webbrowser to"\
           ' test your configuration.'
    end

    private

    def create_config_wizard(config_file, console_config)
      config = Configuration.new

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
# Specifies how often the reporter shall check for newer versions [number of days].
# You may set check-for-updates to 0 to disable
  check-for-updates: 1
  report-class: GrafanaReporter::Asciidoctor::Report
  templates-folder: #{templates}
  reports-folder: #{reports}
  report-retention: #{retention}
  webservice-port: #{port}
# you may want to configure the following webhook callbacks to get informed on certain events
#  callbacks:
#    all:
#      - <<your_callback_url>>
#      - ...
#    on_before_create:
#      - <<your_callback_url>>
#      - ...
#    on_after_cancel:
#      - <<your_callback_url>>
#      - ...
#    on_after_finish:
#      - <<your_callback_url>>
#      - ...

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

      config
    end

    def create_demo_report(config)
      unless Dir.exist?(config.templates_folder)
        puts "Skip creation of DEMO template, as folder '#{config.templates_folder}' does not exist."
        return nil
      end

      create = user_input('Shall I create a demo report for your new configuration file? Please note '\
                          'that this report might contain confidential information, depending on the '\
                          'confidentiality of the information stored in your dashboard.', 'yN')
      return nil unless create =~ /^(?:y|Y)$/

      demo_report = 'demo_report'
      demo_report_file = "#{config.templates_folder}#{demo_report}.#{config.report_class.default_template_extension}"

      # ask to overwrite file
      if File.exist?(demo_report_file)
        input = user_input("Demo template '#{demo_report_file}' does already exist. Do you want to "\
                           'overwrite it?', 'yN')

        case input
        when /^(?:y|Y)$/
          puts 'Overwriting existing DEMO template.'

        else
          puts 'Skip creation of DEMO template.'
          return demo_report
        end
      end

      grafana = ::Grafana::Grafana.new(config.grafana_host, config.grafana_api_key, ssl_disable_verify: config.grafana_ssl_disable_verify)
      demo_report_content = DemoReportWizard.new(config.report_class.demo_report_classes).build(grafana)

      begin
        File.write(demo_report_file, demo_report_content, mode: 'w')
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
      ssl_disable_verify = false
      until valid
        url ||= user_input('Specify grafana host', 'http://localhost:3000')
        print "Testing connection to '#{url}' #{api_key ? '_with_' : '_without_'} API key..."
        begin
          res = Grafana::Grafana.new(url,
                                     api_key,
                                     ssl_disable_verify: ssl_disable_verify,
                                     logger: config.logger).test_connection

        rescue OpenSSL::SSL::SSLError => e
          print(e.message)
          res = 'SSLError'

        rescue StandardError => e
          puts
          puts e.message
        end
        puts 'done.'

        case res
        when 'Admin'
          tmp = user_input('Access to grafana is permitted as Admin, which is a potential security risk.'\
                ' Do you want to use another [a]pi key, [r]e-enter url key or [i]gnore?', 'aRi')

          case tmp
          when /(?:i|I)$/
            valid = true

          when /(?:a|A)$/
            print 'Enter API key: '
            api_key = gets.strip

          else
            url = nil
            api_key = nil

          end

        when 'NON-Admin'
          print 'Access to grafana is permitted as NON-Admin.'
          valid = true

        when 'SSLError'
          tmp = user_input('Could not connect to grafana, because of a SSL connection error. If you are aware of the risks, you can try'\
                           ' to disable the SSL verification. Do you want to [d]isable the SSL verification, [r]e-enter the url or'\
                           ' [i]gnore and proceed?', 'dRi')

          case tmp
          when /(?:i|I)$/
            valid = true

          when /(?:d|D)$/
            ssl_disable_verify = true

          else
            url = nil
            api_key = nil

          end

        else
          tmp = user_input("Grafana could not be accessed at '#{url}'. Do you want to use an [a]pi key,"\
                ' [r]e-enter url, or [i]gnore and proceed?', 'aRi')

          case tmp
          when /(?:i|I)$/
            valid = true

          when /(?:a|A)$/
            print 'Enter API key: '
            api_key = gets.strip

          else
            url = nil
            api_key = nil

          end

        end
      end
      %(grafana:
  default:
    host: #{url}#{api_key ? "\n    api_key: #{api_key}" : ''}#{ssl_disable_verify ? "\n    ssl-disable-verify: #{ssl_disable_verify}" : ''}
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

    def overwrite_or_use_config_file(config_file)
      return 'overwrite' unless File.exist?(config_file)

      input = nil
      until input
        input = user_input("Configuration file '#{config_file}' already exists. Do you want to [o]verwrite it, "\
                           'use it to for [d]emo report creation only, or [a]bort?', 'odA')
      end

      return 'demo_report' if input =~ /^(?:d|D)$/
      return 'abort' if input =~ /^(?:A|a|odA)$/

      'overwrite'
    end
  end
end
