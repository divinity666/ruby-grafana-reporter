# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # Implements the hook
    #   include::grafana_environment[]
    #
    # Shows all available variables, which are accessible during this run of the asciidoctor
    # grafana reporter in a asciidoctor readable form.
    #
    # This processor is very helpful during report template design, to find out the available
    # variables, that can be accessed.
    #
    # == Used document parameters
    # All, to be listed as the available environment.
    #
    # == Supported options
    # +instance+ - grafana instance name, if extended information about the grafana instance shall be printed
    class ShowEnvironmentIncludeProcessor < ::Asciidoctor::Extensions::IncludeProcessor
      include ProcessorMixin

      # :nodoc:
      def handles?(target)
        target.start_with? 'grafana_environment'
      end

      # :nodoc:
      def process(doc, reader, _target, attrs)
        # return if @report.cancel
        @report.next_step
        instance = attrs['instance'] || doc.attr('grafana_default_instance') || 'default'
        attrs['result_type'] = 'sql_table'
        @report.logger.debug('Processing ShowEnvironmentIncludeProcessor')
        grafana = @report.grafana(instance)

        vars = { 'table_formatter' => 'adoc_plain', 'include_headline' => 'true'}
        vars = vars.merge(build_attribute_hash(doc.attributes, attrs))

        # query reporter environment
        result = ['== Reporter', '|===']
        query = QueryValueQuery.new(grafana, variables: vars.merge({'transpose' => 'true'}))
        query.datasource = ::GrafanaReporter::ReporterEnvironmentDatasource.new(nil)
        result += query.execute.split("\n")

        # query grafana environment
        result += ['|===', '',
                   '== Grafana Instance', '|===']
        query = QueryValueQuery.new(grafana, variables: vars.merge({'transpose' => 'true'}))
        query.raw_query = {grafana: grafana, mode: 'general'}
        query.datasource = ::Grafana::GrafanaEnvironmentDatasource.new(nil)
        result += query.execute.split("\n")

        result += ['|===', '',
                   '== Accessible Dashboards', '|===']
        query = QueryValueQuery.new(grafana, variables: vars)
        query.raw_query = {grafana: grafana, mode: 'dashboards'}
        query.datasource = Grafana::GrafanaEnvironmentDatasource.new(nil)
        result += query.execute.split("\n")

        result += ['|===', '',
                   '== Accessible Variables',
                   '|===']
        doc.attributes.sort.each do |k, v|
          result << "| `+{#{k}}+` | #{v}"
        end
        result << '|==='

        reader.unshift_lines result
      end

      # @see ProcessorMixin#build_demo_entry
      def build_demo_entry(_panel)
        'include::grafana_environment[]'
      end
    end
  end
end
