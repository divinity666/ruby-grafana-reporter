# frozen_string_literal: true

require_relative 'processor_mixin'

module GrafanaReporter
  module Asciidoctor
    # Implements the hook
    #   include::grafana_value_as_variable[<options>]
    #
    # Returns an attribute definition in asciidoctor format. This is needed if you want to refer to values of
    # a grafana query within a variable in asciidoctor. As this works without this function for the
    # `IncludeProcessor`s values, it will not work for all the other processors.
    #
    # This method is just a proxy for all other hooks and will forward parameters accordingly.
    #
    # Example:
    #
    #   include:grafana_value_as_variable[call="grafana_sql_value:1",variable_name="my_variable",sql="SELECT 'looks good'",<any_other_option>]
    #
    # This will call the {SqlValueInlineMacro} with `datasource_id` set to `1` and store the result in the
    # variable. The resulting asciidoctor variable definition will be created as:
    #
    #   :my_variable: looks good
    #
    # and can be refered to in your document easily as
    #
    #   {my_variable}
    #
    # == Supported options
    # +call+ - regular call to the reporter hook (*mandatory*)
    #
    # +variable_name+ - name of the variable, to which the result shall be assigned (*mandatory*)
    class ValueAsVariableIncludeProcessor < ::Asciidoctor::Extensions::IncludeProcessor
      include ProcessorMixin

      # :nodoc:
      def handles?(target)
        target.start_with? 'grafana_value_as_variable'
      end

      # :nodoc:
      def process(doc, reader, target, attrs)
        return if @report.cancel

        # increase step for this processor as well as it is also counted in the step counter
        @report.next_step

        call_attr = attrs.delete('call')
        call, target = call_attr.split(':') if call_attr
        attribute = attrs.delete('variable_name')
        @report.logger.debug("Processing ValueAsVariableIncludeProcessor (call: #{call}, target: #{target},"\
                             " variable_name: #{attribute}, attrs: #{attrs})")
        if !call || !attribute
          @report.logger.error('ValueAsVariableIncludeProcessor: Missing mandatory attribute \'call\' or '\
                               '\'variable_name\'.')
          # increase counter, as error occured and no sub call is being processed
          @report.next_step
          return reader
        end

        # TODO: properly show error messages also in document
        ext = doc.extensions.find_inline_macro_extension(call) if doc.extensions.inline_macros?
        if !ext
          @report.logger.error('ValueAsVariableIncludeProcessor: Could not find inline macro extension for '\
                               "'#{call}'.")
          # increase counter, as error occured and no sub call is being processed
          @report.next_step
        else
          @report.logger.debug('ValueAsVariableIncludeProcessor: Calling sub-method.')
          item = ext.process_method.call(doc, target, attrs)
          if !item.text.to_s.empty?
            result = ":#{attribute}: #{item.text}"
            @report.logger.debug("ValueAsVariableIncludeProcessor: Adding '#{result}' to document.")
            reader.unshift_line(result)
          else
            @report.logger.debug("ValueAsVariableIncludeProcessor: Not adding variable '#{attribute}'"\
                                 ' as query result was empty.')
          end
        end

        reader
      end
    end
  end
end
