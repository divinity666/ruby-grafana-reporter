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
      @logger = ::Logger.new($stderr, level: :unknown)
    end

    attr_accessor :logger

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

      "#{templates_folder}#{get_config('default-document-attributes:var-template')}.adoc"
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
    # @return [Hash<String,Integer>] configured datasources for the requested grafana instance. Name as key,
    #   ID as value.
    def grafana_datasources(instance = 'default')
      hash = get_config("grafana:#{instance}:datasources")
      return nil if hash.nil?

      hash.map { |k, v| [k, v] }.to_h
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

    # This function shall be called, before the configuration object is used in the
    # {Application::Application#run}. It ensures, that everything is setup properly
    # and all necessary folders exist. Appropriate errors are raised in case of errors.
    # @return [void]
    def validate
      check_deprecation
      validate_schema(schema, @config)

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
        if cur_pos[subpath]
          cur_pos = cur_pos[subpath]
        else
          cur_pos[subpath] = {}
          cur_pos = cur_pos[subpath]
        end
      end

      cur_pos[last_level] = value
      update_configuration
    end

    # Merge the given configuration object settings with the current config, i.e. overwrite and add all
    # settings from the given config, but keep the not specified configs from the current object.
    #
    # param other_config [Configuration] other configuration object
    def merge!(other_config)
      self.config.merge!(other_config.config) { |_key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2) : v2 }
      update_configuration
    end

    private

    def check_deprecation
      return if report_class

      logger.warn('DEPRECATION WARNING: Your configuration explicitly needs to specify the \'grafana-reporter:report-class\' value. '\
                  'Currently this defaults to \'GrafanaReporter::Asciidoctor::Report\'. You can get rid of this warning, if you explicitly '\
                  'set this configuration in your configuration file. Setting this default will be removed in a future version.')
      set_param('grafana-reporter:report-class', 'GrafanaReporter::Asciidoctor::Report')
    end

    def update_configuration
      if get_config('grafana-reporter:debug-level') =~ /DEBUG|INFO|WARN|ERROR|FATAL|UNKNOWN/
        @logger.level = Object.const_get("::Logger::Severity::#{get_config('grafana-reporter:debug-level')}")
      end

      if get_config('grafana-reporter:report-class')
        self.report_class = Object.const_get(get_config('grafana-reporter:report-class'))
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

    def validate_schema(schema, subject)
      return nil if subject.nil?

      schema.each do |key, config|
        type, min_occurence, next_level = config

        validate_schema(next_level, subject[key]) if next_level

        if key.nil?
          # apply to all on this level
          case
          when subject.is_a?(Hash)
            if subject.length < min_occurence
              raise ConfigurationDoesNotMatchSchemaError.new(key, 'occur', min_occurence, subject.length)
            end

            subject.each do |k, _v|
              sub_scheme = {}
              sub_scheme[k] = schema[nil]
              validate_schema(sub_scheme, subject)
            end

          else
            raise ConfigurationError, "Unhandled configuration data type '#{subject.class}'."
          end

        # apply to single item
        elsif subject.is_a?(Hash)
          if !subject.key?(key) && min_occurence.positive?
            raise ConfigurationDoesNotMatchSchemaError.new(key, 'occur', min_occurence, 0)
          end
          if !subject[key].is_a?(type) && subject.key?(key)
            raise ConfigurationDoesNotMatchSchemaError.new(key, 'be a', type, subject[key].class)
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
          Hash, 1,
          {
            'debug-level' => [String, 0],
            'run-mode' => [String, 0],
            'test-instance' => [String, 0],
            'templates-folder' => [String, 0],
            'report-class' => [String, 1],
            'reports-folder' => [String, 0],
            'report-retention' => [Integer, 0],
            'webservice-port' => [Integer, 0]
          }
        ]
      }
    end
  end
end
