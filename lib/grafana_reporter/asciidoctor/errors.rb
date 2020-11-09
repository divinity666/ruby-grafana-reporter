# frozen_string_literal: true

module GrafanaReporter
  # This module contains all classes, which are necessary to use the grafana
  # reporter to be used in conjunction with asciidoctor.
  module Asciidoctor
    # Thrown, if the value configuration in {QueryMixin#replace_values} is
    # invalid.
    class MalformedReplaceValuesStatementError < GrafanaReporterError
      def initialize(statement)
        super("The specified replace_values statement '#{statement}' is invalid. Make sure it contains"\
              " exactly one not escaped ':' symbol.")
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
end
