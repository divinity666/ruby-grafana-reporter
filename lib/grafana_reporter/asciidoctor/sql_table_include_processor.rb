# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # Implements the hook
    #   include::grafana_sql_table:<datasource_id>[<options>]
    #
    # Returns the results of the SQL query as a asciidoctor table.
    #
    # == Used document parameters
    # +grafana_default_instance+ - name of grafana instance, 'default' if not specified
    #
    # +from+ - 'from' time for the sql query
    #
    # +to+ - 'to' time for the sql query
    #
    # All other variables starting with +var-+ will be used to replace grafana templating strings
    # in the given SQL query.
    #
    # == Supported options
    # +sql+ - sql statement (*mandatory*)
    #
    # +instance+ - name of grafana instance, 'default' if not specified
    #
    # +from+ - 'from' time for the sql query
    #
    # +to+ - 'to' time for the sql query
    #
    # +format+ - see {AbstractQuery#format_columns}
    #
    # +replace_values+ - see {AbstractQuery#replace_values}
    #
    # +filter_columns+ - see {AbstractQuery#filter_columns}
    class SqlTableIncludeProcessor < ::Asciidoctor::Extensions::IncludeProcessor
      include ProcessorMixin

      # :nodoc:
      def handles?(target)
        target.start_with? 'grafana_sql_table:'
      end

      # :nodoc:
      def process(doc, reader, target, attrs)
        return if @report.cancel

        @report.next_step
        instance = attrs['instance'] || doc.attr('grafana_default_instance') || 'default'
        attrs['result_type'] = 'sql_table'
        @report.logger.debug("Processing SqlTableIncludeProcessor (instance: #{instance},"\
                             " datasource: #{target.split(':')[1]}, sql: #{attrs['sql']})")

        begin
          # catch properly if datasource could not be identified
          query = QueryValueQuery.new(@report.grafana(instance), variables: build_attribute_hash(doc.attributes, attrs))
          query.datasource = @report.grafana(instance).datasource_by_id(target.split(':')[1].to_i)
          query.raw_query = attrs['sql']

          reader.unshift_lines query.execute
        rescue GrafanaReporterError => e
          @report.logger.error(e.message)
          reader.unshift_line "|#{e.message}"
        rescue StandardError => e
          @report.logger.fatal(e.message)
          reader.unshift_line "|#{e.message}"
        end

        reader
      end

      # @see ProcessorMixin#build_demo_entry
      def build_demo_entry(panel)
        return nil unless panel
        return nil unless panel.model['type'].include?('table')

        ref_id = nil
        panel.model['targets'].each do |item|
          if !item['hide'] && !panel.query(item['refId']).to_s.empty?
            ref_id = item['refId']
            break
          end
        end
        return nil unless ref_id

        "|===\ninclude::grafana_sql_table:#{panel.dashboard.grafana.datasource_by_name(panel.model['datasource']).id}"\
        "[sql=\"#{panel.query(ref_id).gsub(/"/, '\"').gsub("\n", ' ').gsub(/\\/, '\\\\')}\",filter_columns=\"time\","\
        "dashboard=\"#{panel.dashboard.id}\",from=\"now-1h\",to=\"now\"]\n|==="
      end
    end
  end
end
