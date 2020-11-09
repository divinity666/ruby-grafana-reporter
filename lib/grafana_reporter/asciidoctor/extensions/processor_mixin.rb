# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # The classes within this module implement the interface to asciidoctor. Each class implements a specific extension
    # to asciidoctor.
    module Extensions
      # This module contains common methods for all asciidoctor extensions.
      module ProcessorMixin
        # Used when initializing a object instance, to set the report object, which is currently in progress.
        # @param report [GrafanaReporter::Asciidoctor::Report] current report
        # @return [::Asciidoctor::Extensions::Processor] self
        def current_report(report)
          @report = report
          self
        end
      end
    end
  end
end
