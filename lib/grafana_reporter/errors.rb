module GrafanaReporter
  # General error of the reporter. All other errors will inherit from this class.
  class GrafanaReporterError < StandardError
    def initialize(message)
      super('GrafanaReporterError: ' + message.to_s)
    end
  end

  # Thrown, if the requested grafana instance does not have the mandatory 'host'
  # setting configured.
  class GrafanaInstanceWithoutHostError < GrafanaReporterError
    def initialize(instance)
      super("Grafana instance '#{instance}' has been configured without mandatory 'host' setting.")
    end
  end

  # General configuration error. All configuration errors inherit from this class.
  class ConfigurationError < GrafanaReporterError
    def initialize(message)
      super("Configuration error: #{message}")
    end
  end

  # Thrown, if a configured path does not exist.
  class FolderDoesNotExistError < ConfigurationError
    def initialize(folder, config_item)
      super("#{config_item} '#{folder}' does not exist.")
    end
  end

  # Thrown if the configuration does not match the expected schema.
  # Details about how to fix that are provided in the message.
  class ConfigurationDoesNotMatchSchemaError < ConfigurationError
    def initialize(item, verb, expected, currently)
      super("Configuration file does not match schema definition. Expected '#{item}' to #{verb} '#{expected}', but was '#{currently}'.")
    end
  end
end