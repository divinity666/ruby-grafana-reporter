# frozen_string_literal: true

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
  class Configuration
    # @return [AbstractReport] specific report class, which should be used.
    attr_accessor :report_class
    attr_accessor :logger

    # Default file name for grafana reporter configuration file
    DEFAULT_CONFIG_FILE_NAME = 'grafana_reporter.config'

    # Returned by {#mode} if only a connection test shall be executed.
    MODE_CONNECTION_TEST = 'test'
    # Returned by {#mode} if only one configured report shall be rendered.
    MODE_SINGLE_RENDER = 'single-render'
    # Returned by {#mode} if the default webservice shall be started.
    MODE_SERVICE = 'webservice'

    # Used to access the configuration hash. To make sure, that the configuration is
    # valid, call {#validate}.
    attr_reader :config

    def initialize
      @config = {}
      @logger = ::Logger.new($stderr, level: :info)
    end

    # Reads a given configuration file.
    # @param config_file [String] path to configuration file, defaults to DEFAULT_CONFIG_FILE_NAME
    # @return [Hash] configuration hash to be set as {Configuration#config}
    def load_config_from_file(config_file = nil)
      config_file ||= DEFAULT_CONFIG_FILE_NAME
      self.config = YAML.load_file(config_file)
    rescue StandardError => e
      raise ConfigurationError, "Could not read config file '#{config_file}' (Error: #{e.message})"
    end

    # Used to overwrite the current configuration.
    def config=(new_config)
      @config = new_config
      update_configuration
    end

    # @return [String] mode, in which the reporting shall be executed. One of {MODE_CONNECTION_TEST},
    #   {MODE_SINGLE_RENDER} and {MODE_SERVICE}.
    def mode
      if (get_config('grafana-reporter:run-mode') != MODE_CONNECTION_TEST) &&
         (get_config('grafana-reporter:run-mode') != MODE_SINGLE_RENDER)
        return MODE_SERVICE
      end

      get_config('grafana-reporter:run-mode')
    end

    # @return [String] full path of configured report template. Only needed in {MODE_SINGLE_RENDER}.
    def template
      return nil if get_config('default-document-attributes:var-template').nil?

      "#{templates_folder}#{get_config('default-document-attributes:var-template')}"
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

    # @return [String] configured folder, in which the report templates are stored including trailing slash.
    #   By default: current folder.
    def templates_folder
      result = get_config('grafana-reporter:templates-folder') || '.'
      return result.sub(%r{/*$}, '/') unless result.empty?

      result
    end

    # Returns configured folder, in which temporary images during report generation
    # shall be stored including trailing slash. Folder has to be a subfolder of
    # {#templates_folder}. By default: current folder.
    # @return [String] configured folder, in which temporary images shall be stored.
    def images_folder
      img_path = templates_folder
      img_path = if img_path.empty?
                   get_config('default-document-attributes:imagesdir').to_s
                 else
                   img_path + get_config('default-document-attributes:imagesdir').to_s
                 end
      img_path.empty? ? './' : img_path.sub(%r{/*$}, '/')
    end

    # @return [String] name of grafana instance, against which a test shall be executed
    def test_instance
      get_config('grafana-reporter:test-instance')
    end

    # @return [String] configured folder, in which the reports shall be stored including trailing slash.
    #   By default: current folder.
    def reports_folder
      result = get_config('grafana-reporter:reports-folder') || '.'
      return result.sub(%r{/*$}, '/') unless result.empty?

      result
    end

    # @return [Integer] how many hours a generated report shall be retained, before it shall be deleted.
    #   By default: 24.
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

    # Checks if this is the latest ruby-grafana-reporter version. If and how often the check if
    # performed, depends on the configuration setting `check-for-updates`. By default this is
    # 0 (=disabled). If a number >0 is specified, the checks are performed once every n-days on
    # report creation or call of overview webpage.
    # @return [Boolean] true, if is ok, false if a newer version exists
    def latest_version_check_ok?
      return false if @newer_version_exists

      value = get_config('grafana-reporter:check-for-updates') || 0
      return true if value <= 0

      # repeat check only every n-th day
      if @last_version_check
        return true if (Time.now - @last_version_check) < (value * 24*60*60)
      end

      # check for newer version
      @last_version_check = Time.now
      url = 'https://github.com/divinity666/ruby-grafana-reporter/releases/latest'
      response = Grafana::WebRequest.new(url).execute
      return true if response['location'] =~ /.*[\/v]#{GRAFANA_REPORTER_VERSION.join('.')}$/

      @newer_version_exists = true
      return false
    end

    # This function shall be called, before the configuration object is used in the
    # {Application::Application#run}. It ensures, that everything is setup properly
    # and all necessary folders exist. Appropriate errors are raised in case of errors.
    # @param explicit [Boolean] true, if validation shall expect explicit (wizard) configuration file
    # @return [void]
    def validate(explicit = false)
      check_deprecation
      validate_schema(schema(explicit), @config)

      # check if set folders exist
      raise FolderDoesNotExistError.new(reports_folder, 'reports-folder') unless File.directory?(reports_folder)
      raise FolderDoesNotExistError.new(templates_folder, 'templates-folder') unless File.directory?(templates_folder)
      raise FolderDoesNotExistError.new(images_folder, 'images-folder') unless File.directory?(images_folder)
    end

    # Can be used to configure or overwrite single parameters.
    #
    # @param path [String] path of the paramter to set, e.g. +grafana-reporter:webservice-port+
    # @param value [Object] value to set
    def set_param(path, value)
      return if path.nil?

      levels = path.split(':')
      last_level = levels.pop

      cur_pos = @config
      levels.each do |subpath|
        cur_pos[subpath] = {} unless cur_pos[subpath]
        cur_pos = cur_pos[subpath]
      end

      cur_pos[last_level] = value
      update_configuration
    end

    # Merge the given configuration object settings with the current config, i.e. overwrite and add all
    # settings from the given config, but keep the not specified configs from the current object.
    #
    # param other_config [Configuration] other configuration object
    def merge!(other_config)
      config.merge!(other_config.config) { |_key, v1, v2| v1.is_a?(Hash) && v2.is_a?(Hash) ? v1.merge(v2) : v2 }
      update_configuration
    end

    private

    def check_deprecation
      return if report_class

      logger.warn('DEPRECATION WARNING: Your configuration explicitly needs to specify the '\
                  '\'grafana-reporter:report-class\' value.  Currently this defaults to '\
                  '\'GrafanaReporter::Asciidoctor::Report\'. You can get rid of this warning, if you '\
                  'explicitly set this configuration in your configuration file. Setting this default will be '\
                  'removed in a future version.')
      set_param('grafana-reporter:report-class', 'GrafanaReporter::Asciidoctor::Report')
    end

    def update_configuration
      debug_level = get_config('grafana-reporter:debug-level')
      rep_class = get_config('grafana-reporter:report-class')

      @logger.level = Object.const_get("::Logger::Severity::#{debug_level}") if debug_level =~ /DEBUG|INFO|WARN|
                                                                                                ERROR|FATAL|UNKNOWN/x
      self.report_class = Object.const_get(rep_class) if rep_class
      ::Grafana::WebRequest.ssl_cert = get_config('grafana-reporter:ssl-cert')

      # register callbacks
      callbacks = get_config('grafana-reporter:callbacks')
      return unless callbacks

      callbacks.each do |url, event|
        AbstractReport.add_event_listener(event.to_sym, ReportWebhook.new(url))
      end
    end

    def get_config(path)
      return if path.nil?

      cur_pos = @config
      path.split(':').each do |subpath|
        cur_pos = cur_pos[subpath] if cur_pos
      end
      cur_pos
    end

    def validate_schema(schema, subject, pattern = nil)
      return nil if subject.nil?

      schema.each do |key, config|
        type, min_occurence, pattern, next_level = config

        validate_schema(next_level, subject[key], pattern) if next_level

        if key.nil?
          # apply to all on this level
          raise ConfigurationError, "Unhandled configuration data type '#{subject.class}'." unless subject.is_a?(Hash)

          if subject.length < min_occurence
            raise ConfigurationDoesNotMatchSchemaError.new(key, 'occur', min_occurence, subject.length)
          end

          subject.each do |k, _v|
            sub_scheme = {}
            sub_scheme[k] = schema[nil]
            validate_schema(sub_scheme, subject)
          end

        # apply to single item
        elsif subject.is_a?(Hash)
          if !subject.key?(key) && min_occurence.positive?
            raise ConfigurationDoesNotMatchSchemaError.new(key, 'occur', min_occurence, 0)
          elsif !subject[key].is_a?(type) && subject.key?(key)
            raise ConfigurationDoesNotMatchSchemaError.new(key, 'be a', type, subject[key].class)
          elsif pattern
            # validate for regex
            unless subject[key].to_s =~ pattern
              raise ConfigurationDoesNotMatchSchemaError.new(key, 'match pattern', pattern.inspect, subject[key].to_s)
            end
          end

        else
          raise ConfigurationError, "Unhandled configuration data type '#{subject.class}'."
        end
      end

      # validate also if subject has further configurations, which are not known by the reporter
      subject.each do |item, _subitems|
        schema_config = schema[item] || schema[nil]
        if schema_config.nil?
          logger.warn("Item '#{item}' in configuration is unknown to the reporter and will be ignored")
        end
      end
    end

    def schema(explicit)
      {
        'grafana' =>
         [
           Hash, 1, nil,
           {
             nil =>
              [
                Hash, 1, nil,
                {
                  'host' => [String, 1, %r{^http(s)?://.+}],
                  'api_key' => [String, 0, %r{^(?:[\w]+[=]*)?$}]
                }
              ]
           }
         ],
        'default-document-attributes' => [Hash, explicit ? 1 : 0, nil],
        'to_file' => [String, 0, nil],
        'grafana-reporter' =>
        [
          Hash, 1, nil,
          {
            'check-for-updates' => [Integer, 0, /^[0-9]*$/],
            'debug-level' => [String, 0, /^(?:DEBUG|INFO|WARN|ERROR|FATAL|UNKNOWN)?$/],
            'run-mode' => [String, 0, /^(?:test|single-render|webservice)?$/],
            'test-instance' => [String, 0, nil],
            'templates-folder' => [String, explicit ? 1 : 0, nil],
            'report-class' => [String, 1, nil],
            'reports-folder' => [String, explicit ? 1 : 0, nil],
            'report-retention' => [Integer, explicit ? 1 : 0, nil],
            'ssl-cert' => [String, 0, nil],
            'webservice-port' => [Integer, explicit ? 1 : 0, nil],
            'callbacks' => [Hash, 0, nil, { nil => [String, 1, nil] }]
          }
        ]
      }
    end
  end
end
