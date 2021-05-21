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
      def build(template, destination_file_or_path, custom_attributes)
        attrs = @config.default_document_attributes.merge(@custom_attributes)
        logger.debug("Document attributes: #{attrs}")

        # TODO: if path is true, a default filename has to be generated. check if this should be a general function instead
        File.write(path, ::ERB.new(File.read(template)).result(ReportJail.new(self).bind))

        # TODO: check if closing output file is correct here, or maybe can be moved to AbstractReport.done!
        @destination_file_or_path.close if @destination_file_or_path.is_a?(File)
      end

      # @see AbstractReport#demo_report_classes
      def self.demo_report_classes
        []
      end
    end
  end
end
