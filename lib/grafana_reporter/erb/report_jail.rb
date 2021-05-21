# frozen_string_literal: true

module GrafanaReporter
  module ERB
    # An instance of this class is used as binding for the ERB execution, i.e.
    # this class contains everything known within the ERB template
    class ReportJail
      attr_reader :report

      # TODO: make all variables including URL parameters available to ERB jail
      def initialize(report)
        @report = report
        binding
      end

      # @return binding to this object
      def bind
        binding
      end
    end
  end
end
