# frozen_string_literal: true

module GrafanaReporter
  # General error of the reporter. All other errors will inherit from this class.
  class GrafanaReporterError < StandardError
    def initialize(message)
      super("GrafanaReporterError: #{message}")
    end
  end

  # Raised if a datasource shall be queried, which is not (yet) supported by the reporter
  class DatasourceNotSupportedError < GrafanaReporterError
    def initialize(datasource, query)
      super("The datasource '#{datasource.name}' is of type '#{datasource.type}' which is currently "\
            "not supported for the query type '#{query}'.")
    end
  end

  # Raised if some unhandled exception is raised during a datasource request execution.
  class DatasourceRequestInternalError < GrafanaReporterError
    def initialize(datasource, message)
      super("The datasource request to '#{datasource.name}' (#{datasource.class}) failed with "\
            "an internal error: #{message}")
    end
  end

  # Raised if the return value of a datasource request does not match the expected return hash.
  class DatasourceRequestInvalidReturnValueError < GrafanaReporterError
    def initialize(datasource, message)
      super("The datasource request to '#{datasource.name}' (#{datasource.class}) "\
            "returned an invalid value: '#{message}'")
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

  # Thrown if a non existing template has been specified.
  class MissingTemplateError < ConfigurationError
    def initialize(template)
      super("Accessing report template file '#{template}' is not possible. Check if file exists and is accessible.")
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
      super("Configuration file does not match schema definition. Expected '#{item}' to #{verb} '#{expected}', "\
            "but was '#{currently}'.")
    end
  end

  # Thrown, if the value configuration in {AbstractQuery#replace_values} is
  # invalid.
  class MalformedReplaceValuesStatementError < GrafanaReporterError
    def initialize(statement)
      super("The specified replace_values statement '#{statement}' is invalid. Make sure it contains"\
            " exactly one not escaped ':' symbol.")
    end
  end

  # Thrown, if the value configuration in {QueryValueQuery#select_value} is
  # invalid.
  class UnsupportedSelectValueStatementError < GrafanaReporterError
    def initialize(statement)
      super("Unsupported 'select_value' specified in template file: '#{statement}'. Supported values are 'min', 'max', "\
            "'avg', 'sum', 'first', 'last'.")
    end
  end

  # Thrown, if a configured parameter is malformed.
  class MalformedAttributeContentError < GrafanaReporterError
    def initialize(message, attribute, content)
      super("The content '#{content}' in attribute '#{attribute}' is malformed: #{message}")
    end
  end

  # Thrown, if a configured time range is not supported by the reporter.
  #
  # If this happens, most likely the reporter has to implement the new
  # time range definition.
  class TimeRangeUnknownError < GrafanaReporterError
    def initialize(time_range)
      super("The specified time range '#{time_range}' is unknown.")
    end
  end

  # Thrown, if a mandatory attribute is not set.
  class MissingMandatoryAttributeError < GrafanaReporterError
    def initialize(attribute)
      super("Missing mandatory attribute '#{attribute}'.")
    end
  end
end
