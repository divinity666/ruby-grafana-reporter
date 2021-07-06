# frozen_string_literal: true

require 'erb'

module GrafanaReporter
  module ERB
    # Implementation of a specific {AbstractReport}. It is used to
    # build reports specifically for erb templates.
    class Report < ::GrafanaReporter::AbstractReport
      # Starts to create an asciidoctor report. It utilizes all extensions in the {GrafanaReporter::Asciidoctor}
      # namespace to realize the conversion.
      # @see AbstractReport#build
      def build
        attrs = @config.default_document_attributes.merge(@custom_attributes)
        logger.debug("Document attributes: #{attrs}")

        File.write(path, ::ERB.new(File.read(@template)).result(ReportJail.new(self, attrs).bind))
      end

      # @see AbstractReport#default_template_extension
      def self.default_template_extension
        'erb'
      end

      # @see AbstractReport#default_result_extension
      def self.default_result_extension
        'txt'
      end

      # @see AbstractReport#demo_report_classes
      def self.demo_report_classes
        [DemoReportBuilder]
      end
    end
  end
end
