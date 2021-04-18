# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # This module contains common methods for all asciidoctor extensions.
    module ProcessorMixin
      # Used when initializing a object instance, to set the report object, which is currently in progress.
      # @param report [GrafanaReporter::Asciidoctor::Report] current report
      # @return [::Asciidoctor::Extensions::Processor] self
      def current_report(report)
        @report = report
        self
      end

      # This method is called if a demo report shall be built for the given {Grafana::Panel}.
      # @param panel [Grafana::Panel] panel object, for which a demo entry shall be created.
      # @return [String] String containing the entry, or nil if not possible for given panel
      def build_demo_entry(panel)
        raise NotImplementedError
      end
    end
  end
end
