# frozen_string_literal: true

module GrafanaReporter
  # This module contains all classes, which are necessary to use the reporter in conjunction with asciidoctor.
  module Asciidoctor
    # Implementation of a specific {AbstractReport}. It is used to
    # build reports specifically for asciidoctor results.
    class Report < ::GrafanaReporter::AbstractReport
      # (see AbstractReport#initialize)
      def initialize(config, template, destination_file_or_path = nil, custom_attributes = {})
        super
        @current_pos = 0
        @image_files = []
        @grafana_instances = {}
      end

      # Starts to create an asciidoctor report. It utilizes all extensions in the {GrafanaReporter::Asciidoctor}
      # namespace to realize the conversion.
      # @see AbstractReport#create_report
      # @return [void]
      def create_report
        super
        attrs = { 'convert-backend' => 'pdf' }.merge(@config.default_document_attributes.merge(@custom_attributes))
        attrs['grafana-report-timestamp'] = @start_time.to_s
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

        @destination_file_or_path.close if @destination_file_or_path.is_a?(File)

        # store report including als images as ZIP file, if the result is not a PDF
        if attrs['convert-backend'] != 'pdf'
          dest_path = if @destination_file_or_path.is_a?(File) || @destination_file_or_path.is_a?(Tempfile)
                        @destination_file_or_path.path
                      else
                        @destination_file_or_path
                      end

          # build zip file
          zip_file = Tempfile.new('gf_zip')
          buffer = Zip::OutputStream.write_buffer do |zipfile|
            # add report file
            zipfile.put_next_entry("#{dest_path.gsub(@config.reports_folder, '')}.#{attrs['convert-backend']}")
            zipfile.write File.read(dest_path)

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
            File.write(dest_path, zip_file.read)
          rescue StandardError => e
            logger.fatal("Could not overwrite report file '#{dest_path}' with ZIP file. (#{e.message}).")
          end

          # cleanup temporary zip file
          zip_file.close
          zip_file.unlink
        end

        clean_image_files
        done!
      rescue StandardError => e
        # catch all errors during execution
        died_with_error(e)
        raise e
      end

      # @see AbstractReport#progress
      # @return [Float] number between 0 and 1 reflecting the current progress.
      def progress
        return 0 if @total_steps.to_i.zero?

        @current_pos.to_f / @total_steps
      end

      # @param instance [String] requested grafana instance
      # @return [Grafana::Grafana] the requested grafana instance.
      def grafana(instance)
        unless @grafana_instances[instance]
          @grafana_instances[instance] = ::Grafana::Grafana.new(@config.grafana_host(instance),
                                                                @config.grafana_api_key(instance),
                                                                logger: @logger)
        end
        @grafana_instances[instance]
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
