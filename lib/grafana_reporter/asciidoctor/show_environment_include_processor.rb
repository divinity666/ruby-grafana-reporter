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
        @report.logger.debug('Processing ShowEnvironmentIncludeProcessor')

        vars = ['== Reporter',
                '|===',
                "| Version | #{GRAFANA_REPORTER_VERSION.join('.')}",
                "| Build date | #{GRAFANA_REPORTER_RELEASE_DATE}",
                '|===']

        if attrs['instance']
          grafana = @report.grafana(attrs['instance'])

          vars += ['== Grafana Instance',
                   '|===',
                   "| Instance name | #{attrs['instance']}",
                   "| Version | #{grafana.version}",
                   "| Organization | #{grafana.organization['name']} (ID: #{grafana.organization['id']})",
                   "| Access permissions | #{grafana.test_connection}",
                   '|===',
                   '',
                   '== Accessible Dashboards',
                   '|===',
                   '| Dashboard ID | Dashboard name | # Panels']
          grafana.dashboard_ids.each do |id|
            vars << "| #{id} | #{grafana.dashboard(id).title} | #{grafana.dashboard(id).panels.length}"
          end
          vars << '|==='
        end

        vars += ['== Accessible Variables',
                '|===']
        doc.attributes.sort.each do |k, v|
          vars << "| `+{#{k}}+` | #{v}"
        end
        vars << '|==='

        reader.unshift_lines vars
      end

      # @see ProcessorMixin#build_demo_entry
      def build_demo_entry(_panel)
        'include::grafana_environment[]'
      end
    end
  end
end
