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

      # Starts to create an asciidoctor report. It utilizes all extensions in the {GrafanaReporter::Asciidoctor}
      # namespace to realize the conversion.
      # @see AbstractReport#create_report
      def create_report(template, destination_file_or_path = nil, custom_attributes = {})
        super
        attrs = @config.default_document_attributes.merge(@custom_attributes)
        logger.debug("Document attributes: #{attrs}")

        initialize_step_counter

        # TODO: if path is true, a default filename has to be generated. check if this should be a general function instead
        @report = self
        File.write(path, ::ERB.new(File.read(template)).result(binding))

        # TODO: check if closing output file is correct here, or maybe can be moved to AbstractReport.done!
        @destination_file_or_path.close if @destination_file_or_path.is_a?(File)

        clean_image_files
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

      # TODO: check which following methods can be moved to AbstractReport
      # @see AbstractReport#progress
      # @return [Float] number between 0 and 1 reflecting the current progress.
      def progress
        return @current_pos.to_i if @total_steps.to_i.zero?

        @current_pos.to_f / @total_steps
      end

      # Increments the progress.
      # @return [Integer] number of the current progress position.
      def next_step
        @current_pos += 1
        @current_pos
      end

      # Called to save a temporary image file. After the final generation of the
      # report, these temporary files will automatically be removed.
      # @param img_data [String] image file raw data, which shall be saved
      # @return [String] path to the temporary file.
      def save_image_file(img_data)
        file = Tempfile.new(['gf_image_', '.png'], @config.images_folder.to_s)
        file.write(img_data)
        path = file.path.gsub(/#{@config.images_folder}/, '')

        @image_files << file
        file.close

        path
      end

      # Called, if the report generation has died with an error.
      # @param error [StandardError] occured error
      # @return [void]
      def died_with_error(error)
        @error = [error.message] << [error.backtrace]
        done!
      end

      # @see AbstractReport#demo_report_classes
      def self.demo_report_classes
        []
      end

      private

      def clean_image_files
        @image_files.each(&:unlink)
        @image_files = []
      end

      def initialize_step_counter
        @total_steps = 0
        # TODO: implement initialize_step_counter
      end
    end
  end
end
