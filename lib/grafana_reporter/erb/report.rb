# frozen_string_literal: true

require 'erb'

module GrafanaReporter
  module ERB
    # Implementation of a specific {AbstractReport}. It is used to
    # build reports specifically for erb templates.
    class Report < ::GrafanaReporter::AbstractReport
      # @see AbstractReport#initialize
      def initialize(config)
        super
        @image_files = []
      end

      # Starts to create an erb report. It utilizes all extensions in the {GrafanaReporter::ERB}
      # namespace to realize the conversion.
      # @see AbstractReport#build
      def build
        attrs = @config.default_document_attributes.merge(@custom_attributes).merge({ 'grafana_report_timestamp' => ::Grafana::Variable.new(Time.now.to_s) })
        logger.debug("Document attributes: #{attrs}")

        File.write(path, ::ERB.new(File.read(@template)).result(ReportJail.new(self, attrs).bind))

        zip_report(path, @config.reports_folder, @config.report_class.default_result_extension, @config.images_folder, @image_files)

        clean_image_files
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
