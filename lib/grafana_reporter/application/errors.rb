# frozen_string_literal: true

module GrafanaReporter
  module Application
    # General grafana application error, from which the specific errors
    # inherit.
    class ApplicationError < GrafanaReporterError
    end

    # Thrown, if the '-s' parameter is not configured with exactly one variable
    # name and one value.
    class ParameterValueError < ApplicationError
      def initialize(length)
        super("Parameter '-s' needs exactly two values separated by comma, received #{length}.")
      end
    end

    # Thrown, if a webservice request has been requested, which could not be
    # handled.
    class WebserviceUnknownPathError < ApplicationError
      def initialize(request)
        super("Request '#{request}' calls an unknown path for this webservice.")
      end
    end

    # Thrown, if an internal error appeared during creation of the report.
    class WebserviceGeneralRenderingError < ApplicationError
      def initialize(error)
        super("Could not render report because of internal error: #{error}")
      end
    end
  end
end
