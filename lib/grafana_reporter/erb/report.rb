# frozen_string_literal: true

require 'erb'

module GrafanaReporter
  module ERB
    # Implementation of a specific {AbstractReport}. It is used to
    # build reports specifically for erb templates.
    class Report < ::GrafanaReporter::AbstractReport
      # Starts to create an asciidoctor report. It utilizes all extensions in the {GrafanaReporter::Asciidoctor}
      # namespace to realize the conversion.
      # @see AbstractReport#create_report
      def create_report(template, destination_file_or_path = nil, custom_attributes = {})
        super
        attrs = @config.default_document_attributes.merge(@custom_attributes)
        logger.debug("Document attributes: #{attrs}")

        # TODO: if path is true, a default filename has to be generated. check if this should be a general function instead
        @report = self
        File.write(path, ::ERB.new(File.read(template)).result(binding))

        # TODO: check if closing output file is correct here, or maybe can be moved to AbstractReport.done!
        @destination_file_or_path.close if @destination_file_or_path.is_a?(File)
      rescue MissingTemplateError => e
        @logger.error(e.message)
        @error = [e.message]
        done!
        raise e
      rescue StandardError => e
        # catch all errors during execution
        died_with_error(e)
        raise e
      ensure
        done!
      end

      # @see AbstractReport#demo_report_classes
      def self.demo_report_classes
        []
      end
    end
  end
end
