# In this namespace all objects needed for the grafana reporter are collected.
module GrafanaReporter
  # Used to store the whole settings, which are necessary to run the reporter.
  # It can read configuration files, but might also be configured programmatically.
  #
  # This class also contains a function {#validate}, which ensures that the
  # provided settings are set properly.
  #
  # Using this class is embedded in the {Application::Application#configure_and_run}.
  #
  # TODO add config example
  class Configuration
    # @return [AbstractReport] specific report class, which should be used.
    attr_accessor :report_class

    # Returned by {#mode} if only a connection test shall be executed.
    MODE_CONNECTION_TEST = 'test'
    # Returned by {#mode} if only one configured report shall be rendered.
    MODE_SINGLE_RENDER = 'single-render'
    # Returned by {#mode} if the default webservice shall be started.
    MODE_SERVICE = 'webservice'

    def initialize
      @config = {}
      @logger = ::Logger.new(STDERR, level: :unknown)
      # TODO: set report class somewhere else, but make it known here
      self.report_class = Asciidoctor::Report
    end

    attr_reader :logger

    # @return [String] mode, in which the reporting shall be executed. One of {MODE_CONNECTION_TEST}, {MODE_SINGLE_RENDER} and {MODE_SERVICE}.
    def mode
      return MODE_SERVICE if get_config('grafana-reporter:run-mode') != MODE_CONNECTION_TEST and get_config('grafana-reporter:run-mode') != MODE_SINGLE_RENDER

      return get_config('grafana-reporter:run-mode')
    end

    # @return [String] configured report template. Only needed in {MODE_SINGLE_RENDER}.
    def template
      get_config('default-document-attributes:var-template')
    end

    # @return [String] destination filename for the report in {MODE_SINGLE_RENDER}.
    def to_file
      return get_config('to_file') || true if mode == MODE_SINGLE_RENDER

      get_config('to_file')
    end

    # @return [Array<String>] names of the configured grafana_instances.
    def grafana_instances
      instances = get_config('grafana')
      instances.keys
    end

    # @param instance [String] grafana instance name, for which the value shall be retrieved.
    # @return [String] configured 'host' for the requested grafana instance.
    def grafana_host(instance = 'default')
      host = get_config("grafana:#{instance}:host")
      raise GrafanaInstanceWithoutHostError, instance if host.nil?

      host
    end

    # @param instance [String] grafana instance name, for which the value shall be retrieved.
    # @return [String] configured 'api_key' for the requested grafana instance.
    def grafana_api_key(instance = 'default')
      get_config("grafana:#{instance}:api_key")
    end

    # @param instance [String] grafana instance name, for which the value shall be retrieved.
    # @return [Hash<String,Integer>] configured datasources for the requested grafana instance. Name as key, ID as value.
    def grafana_datasources(instance = 'default')
      hash = get_config("grafana:#{instance}:datasources")
      return nil if hash.nil?

      hash.map { |k, v| [k, v] }.to_h
    end

    # @return [String] configured folder, in which the report templates are stored including trailing slash. By default: current folder.
    def templates_folder
      result = get_config('grafana-reporter:templates-folder') || '.'
      result.sub!(%r{[/]*$}, '/') unless result.empty?
      result
    end

    # Returns configured folder, in which temporary images during report generation
    # shall be stored including trailing slash. Folder has to be a subfolder of
    # {#templates_folder}. By default: current folder.
    # @return [String] configured folder, in which temporary images shall be stored.
    def images_folder
      img_path = templates_folder
      img_path = img_path.empty? ? get_config('default-document-attributes:imagesdir').to_s : img_path + get_config('default-document-attributes:imagesdir').to_s
      img_path.empty? ? './' : img_path.sub(%r{[/]*$}, '/')
    end

    # @return [String] name of grafana instance, against which a test shall be executed
    def test_instance
      get_config('grafana-reporter:test-instance')
    end

    # @return [String] configured folder, in which the reports shall be stored including trailing slash. By default: current folder.
    def reports_folder
      result = get_config('grafana-reporter:reports-folder') || '.'
      result.sub!(%r{[/]*$}, '/') unless result.empty?
      result
    end

    # @return [Integer] how many hours a generated report shall be retained, before it shall be deleted. By default: 24.
    def report_retention
      get_config('grafana-reporter:report-retention') || 24
    end

    # @return [Integer] port, on which the webserver shall run. By default: 8815.
    def webserver_port
      get_config('grafana-reporter:webservice-port') || 8815
    end

    # The configuration made with the setting 'default-document-attributes' will
    # be passed 1:1 to the asciidoctor report service. It can be used to preconfigure
    # whatever is essential for the needed report renderings.
    # @return [Hash] configured document attributes
    def default_document_attributes
      get_config('default-document-attributes') || {}
    end

    # Used to load the configuration of a file or a manually created Hash to this
    # object. To make sure, that the configuration is valid, call {#validate}.
    #
    # NOTE: This function overwrites all existing configurations
    # @param hash [Hash] configuration settings
    # @return [void]
    def load_config(hash)
      @config = hash
    end

    # Used to do the configuration by a command line call. Therefore also help will
    # be shown, in case no parameter has been given.
    # @param params [Array<String>] command line parameters, mainly ARGV can be used.
    # @return [Integer] 0 if everything is fine, -1 if execution shall be aborted.
    def configure_by_command_line(params = [])
      params << '--help' if params.empty?

      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: ruby ruby-grafana-reporter.rb CONFIG_FILE [options]'

        opts.on('-d', '--debug LEVEL', 'Specify detail level: FATAL, ERROR, WARN, INFO, DEBUG.') do |level|
          @logger.level = Object.const_get("::Logger::Severity::#{level}") if level =~ /(?:FATAL|ERROR|WARN|INFO|DEBUG)/
        end

        opts.on('--test GRAFANA_INSTANCE', 'test current configuration against given GRAFANA_INSTANCE') do |instance|
          if get_config('grafana-reporter')
            @config['grafana-reporter']['run-mode'] = 'test'
          else
            @config.merge!({'grafana-reporter' => {'run-mode' => 'test'} })
	  end
          @config['grafana-reporter']['test-instance'] = instance
        end

        opts.on('-t', '--template TEMPLATE', 'Render a single ASCIIDOC template to PDF and exit') do |template|
          if get_config('grafana-reporter')
            @config['grafana-reporter']['run-mode'] = 'single-render'
          else
            @config.merge!({'grafana-reporter' => {'run-mode' => 'single-render'} })
	  end
          @config['default-document-attributes']['var-template'] = template
        end

        opts.on('-o', '--output FILE', 'Output filename if only a single file is rendered') do |file|
          @config.merge!({ 'to_file' => file })
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
            load_config(YAML.load_file(config_file))
          rescue StandardError => e
            raise ConfigurationError, "Could not read CONFIG_FILE '#{config_file}' (Error: #{e.message})"
          end
        end
      end
      parser.parse!(params)

      0
    end

    # This function shall be called, before the configuration object is used in the
    # {Application::Application#run}. It ensures, that everything is setup properly
    # and all necessary folders exist. Appropriate errors are raised in case of errors.
    # @return [void]
    def validate
      validate_schema(schema, @config)

      # check if set folders exist
      raise FolderDoesNotExistError.new(reports_folder, 'reports-folder') unless File.directory?(reports_folder)
      raise FolderDoesNotExistError.new(templates - folder, 'templates-folder') unless File.directory?(templates_folder)
      raise FolderDoesNotExistError.new(images - folder, 'images-folder') unless File.directory?(images_folder)
    end

    private

    def get_config(path)
      return if path.nil?

      cur_pos = @config
      path.split(':').each do |subpath|
        cur_pos = cur_pos[subpath] if cur_pos
      end
      cur_pos
    end

    def validate_schema(schema, subject)
      return nil if subject.nil?

      schema.each do |key, config|
        type, min_occurence, next_level = config

        validate_schema(next_level, subject[key]) if next_level

        if key.nil?
          # apply to all on this level
          if subject.is_a?(Hash)
            if subject.length < min_occurence
              raise ConfigurationDoesNotMatchSchemaError.new(key, 'occur', min_occurence, subject.length)
            end

            subject.each do |k, _v|
              sub_scheme = {}
              sub_scheme[k] = schema[nil]
              validate_schema(sub_scheme, subject)
            end

          elsif subject.is_a?(Array)
            if subject.length < min_occurence
              raise ConfigurationDoesNotMatchSchemaError.new(key, 'occur', min_occurence, subject.length)
            end

            subject.each_index do |i|
              sub_scheme = {}
              sub_scheme[i] = schema[nil]
              validate_schema(sub_scheme, subject)
            end

          else
            raise ConfigurationError, "Unhandled configuration data type '#{subject.class}'."
          end
        else
          # apply to single item
          if subject.is_a?(Hash)
            if !subject.key?(key) && (min_occurence > 0)
              raise ConfigurationDoesNotMatchSchemaError.new(key, 'occur', min_occurence, 0)
            end
            if !subject[key].is_a?(type) && subject.key?(key)
              raise ConfigurationDoesNotMatchSchemaError.new(key, 'be a', type, subject[key].class)
            end

          elsif subject.is_a?(Array)
            if (subject.length < key) && (min_occurence > subject.length)
              raise ConfigurationDoesNotMatchSchemaError.new(key, 'occur', min_occurence, subject.length)
            end
            if !subject[key].is_a?(type) && (subject.length >= key)
              raise ConfigurationDoesNotMatchSchemaError.new(key, 'be a', type, subject[key].class)
            end

          else
            raise ConfigurationError, "Unhandled configuration data type '#{subject.class}'."
          end
        end
      end

      # validate also if subject has further configurations, which are not known by the reporter
      subject.each do |item, subitems|
        schema_config = schema[item] || schema[nil]
        if schema_config.nil?
          logger.warn("Item '#{item}' in configuration is unknown to the reporter and will be ignored")
        end
      end
    end

    def schema
      {
        'grafana' =>
         [
           Hash, 1,
           {
             nil =>
              [
                Hash, 1,
                {
                  'host' => [String, 1],
                  'api_key' => [String, 0],
                  'datasources' => [Hash, 0, { nil => [Integer, 1] }]
                }
              ]
           }
         ],
        'default-document-attributes' => [Hash, 0],
        'grafana-reporter' =>
        [
          Hash, 0,
          {
            'run-mode' => [String, 0],
            'test-instance' => [String, 0],
            'templates-folder' => [String, 0],
            'reports-folder' => [String, 0],
            'report-retention' => [Integer, 0],
            'webservice-port' => [Integer, 0]
          }
        ]
      }
    end
  end
end
