module GrafanaReporter
  module Application
    # General grafana application error, from which the specific errors
    # inherit.
    class ApplicationError < GrafanaReporterError
    end

    # Thrown if a non existing template has been specified.
    class MissingTemplateError < ApplicationError
      def initialize(template)
        super("Given report template '#{template}' is not a valid template.")
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
