# frozen_string_literal: true

require 'erb'

module GrafanaReporter
  module ERB
    # Implementation of a specific {AbstractReport}. It is used to
    # build reports specifically for erb templates.
    class Report < ::GrafanaReporter::AbstractReport
      # Starts to create an erb report. It utilizes all extensions in the {GrafanaReporter::ERB}
      # namespace to realize the conversion.
      # @see AbstractReport#build
      def build
        attrs = @config.default_document_attributes.merge(@custom_attributes).merge({ 'grafana_report_timestamp' => ::Grafana::Variable.new(Time.now.to_s) })
        logger.debug("Document attributes: #{attrs}")

        File.write(path, ::ERB.new(File.read(@template)).result(ReportJail.new(self, attrs).bind))

        # build zip file
        zip_file = Tempfile.new('gf_zip')
        buffer = Zip::OutputStream.write_buffer do |zipfile|
          # add report file
          zipfile.put_next_entry("#{path.gsub(@config.reports_folder, '')}.#{@config.report_class.default_result_extension}")
          zipfile.write File.read(path)
        end
        File.open(zip_file, 'wb') do |f|
          f.write buffer.string
        end

        # replace original file with zip file
        zip_file.rewind
        begin
          File.write(path, zip_file.read)
        rescue StandardError => e
          logger.fatal("Could not overwrite report file '#{path}' with ZIP file. (#{e.message}).")
        end
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
