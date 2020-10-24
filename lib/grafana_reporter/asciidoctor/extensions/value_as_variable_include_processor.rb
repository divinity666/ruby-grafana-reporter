require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
    module Extensions
      # TODO: add documentation
      class ValueAsVariableIncludeProcessor < ::Asciidoctor::Extensions::IncludeProcessor
        include ProcessorMixin

        # :nodoc:
        def handles?(target)
          target.start_with? 'grafana_value_as_variable'
        end

        # :nodoc:
        def process(doc, reader, target, attrs)
          return if @report.cancel

          # do NOT increase step, as this is done by sub processor
          #@report.next_step

          call_attr = attrs.delete('call')
          call, target = call_attr.split(":") if call_attr
          attribute = attrs.delete('variable_name')
          @report.logger.debug("Processing ValueAsVariableIncludeProcessor (call: #{call}, target: #{target}, variable_name: #{attribute}, attrs: #{attrs.to_s})")
          if not call or not attribute
            @report.logger.error("Missing mandatory attribute 'call' or 'variable_name'.")
            return reader
          end

          # TODO: remove dirty hack to allow the document as parameter for other processors
          def doc.document
            self
          end
          
          # TODO: properly show error messages also in document
          ext = doc.extensions.find_inline_macro_extension(call) if doc.extensions.inline_macros?
          if not ext
            @report.logger.error("Could not find inline macro extension for '#{call}'.")
          else
            @report.logger.debug("ValueAsVariableIncludeProcessor: Calling sub-method.")
            item = ext.process_method.call(doc, target, attrs)
            if not item.text.to_s.empty?
	      result = ":#{attribute}: #{item.text}"
              @report.logger.debug("ValueAsVariableIncludeProcessor: Adding '#{result}' to document.")
              reader.unshift_line(result)
            else
              @report.logger.debug("ValueAsVariableIncludeProcessor: Not adding variable '#{attribute}', as query result was empty.")
            end
          end
          
          reader
        end
      end
    end
  end
end
