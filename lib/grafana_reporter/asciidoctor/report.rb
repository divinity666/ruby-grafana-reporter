# frozen_string_literal: true

module GrafanaReporter
  # This module contains all classes, which are necessary to use the reporter in conjunction with asciidoctor.
  module Asciidoctor
    # Implementation of a specific {AbstractReport}. It is used to
    # build reports specifically for asciidoctor results.
    class Report < ::GrafanaReporter::AbstractReport
      # @see AbstractReport#initialize
      def initialize(config)
        super
        @image_files = []
      end

      # Starts to create an asciidoctor report. It utilizes all extensions in the {GrafanaReporter::Asciidoctor}
      # namespace to realize the conversion.
      # @see AbstractReport#build
      def build
        attrs = { 'convert-backend' => 'pdf' }.merge(@config.default_document_attributes.merge(@custom_attributes))
        logger.debug("Document attributes: #{attrs}")

        initialize_step_counter

        # register necessary extensions for the current report
        ::Asciidoctor::LoggerManager.logger = logger

        registry = ::Asciidoctor::Extensions::Registry.new
        registry.inline_macro PanelImageInlineMacro.new.current_report(self)
        registry.inline_macro PanelQueryValueInlineMacro.new.current_report(self)
        registry.inline_macro PanelPropertyInlineMacro.new.current_report(self)
        registry.inline_macro SqlValueInlineMacro.new.current_report(self)
        registry.block_macro PanelImageBlockMacro.new.current_report(self)
        registry.include_processor ValueAsVariableIncludeProcessor.new.current_report(self)
        registry.include_processor PanelQueryTableIncludeProcessor.new.current_report(self)
        registry.include_processor SqlTableIncludeProcessor.new.current_report(self)
        registry.include_processor ShowEnvironmentIncludeProcessor.new.current_report(self)
        registry.include_processor ShowHelpIncludeProcessor.new.current_report(self)
        registry.include_processor AnnotationsTableIncludeProcessor.new.current_report(self)
        registry.include_processor AlertsTableIncludeProcessor.new.current_report(self)

        ::Asciidoctor.convert_file(@template, extension_registry: registry, backend: attrs['convert-backend'],
                                              to_file: path, attributes: attrs, header_footer: true)

        # store report including als images as ZIP file, if the result is not a PDF
        if attrs['convert-backend'] != 'pdf'
          # build zip file
          zip_file = Tempfile.new('gf_zip')
          buffer = Zip::OutputStream.write_buffer do |zipfile|
            # add report file
            zipfile.put_next_entry("#{path.gsub(@config.reports_folder, '')}.#{attrs['convert-backend']}")
            zipfile.write File.read(path)

            # add image files
            @image_files.each do |file|
              zipfile.put_next_entry(file.path.gsub(@config.images_folder, ''))
              zipfile.write File.read(file.path)
            end
          end
          File.open(zip_file, 'wb') do |f|
            f.write buffer.string
          end

          # replace original file with zip file
          zip_file.rewind
          begin
            File.write(path, zip_file.read)
          rescue StandardError => e
            logger.fatal("Could not overwrite file '#{path}' with zipped file. (#{e.message}).")
          end

          # cleanup temporary zip file
          zip_file.close
          zip_file.unlink
        end

        clean_image_files
      end

      # Called to save a temporary image file. After the final generation of the
      # report, these temporary files will automatically be removed.
      # @param img_data [String] image file raw data, which shall be saved
      # @return [String] path to the temporary file.
      def save_image_file(img_data)
        file = Tempfile.new(['gf_image_', '.png'], @config.images_folder.to_s)
        file.binmode
        file.write(img_data)
        path = file.path.gsub(/#{@config.images_folder}/, '')

        @image_files << file
        file.close

        path
      end

      # @see AbstractReport#default_template_extension
      def self.default_template_extension
        'adoc'
      end

      # @see AbstractReport#default_result_extension
      def self.default_result_extension
        'pdf'
      end

      # @see AbstractReport#demo_report_classes
      def self.demo_report_classes
        [AlertsTableIncludeProcessor, AnnotationsTableIncludeProcessor, PanelImageBlockMacro, PanelImageInlineMacro,
         PanelPropertyInlineMacro, PanelQueryTableIncludeProcessor, PanelQueryValueInlineMacro,
         SqlTableIncludeProcessor, SqlValueInlineMacro, ShowHelpIncludeProcessor, ShowEnvironmentIncludeProcessor]
      end

      private

      def clean_image_files
        @image_files.each(&:unlink)
        @image_files = []
      end

      def initialize_step_counter
        @total_steps = 0
        File.readlines(@template).each do |line|
          begin
            # TODO: move these calls to the specific processors to ensure all are counted properly
            @total_steps += line.gsub(%r{//.*}, '').scan(/(?:grafana_panel_image|grafana_panel_query_value|
                                                         grafana_panel_query_table|grafana_sql_value|
                                                         grafana_sql_table|grafana_environment|grafana_help|
                                                         grafana_panel_property|grafana_annotations|grafana_alerts|
                                                         grafana_value_as_variable)/x).length
          rescue StandardError => e
            logger.error("Could not process line '#{line}' (Error: #{e.message})")
            raise e
          end
        end
        logger.debug("Template #{@template} contains #{@total_steps} calls of grafana reporter functions.")
      end
    end
  end
end
