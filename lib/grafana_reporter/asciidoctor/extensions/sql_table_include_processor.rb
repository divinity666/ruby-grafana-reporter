module GrafanaReporter
  module Asciidoctor
    module Extensions
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
      # +format+ - see {QueryMixin#format_columns}
      #
      # +replace_values+ - see {QueryMixin#replace_values}
      #
      # +filter_columns+ - see {QueryMixin#filter_columns}
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
          @report.logger.debug("Processing SqlTableIncludeProcessor (instance: #{instance}, datasource: #{target.split(':')[1]}, sql: #{attrs['sql']})")
          query = SqlTableQuery.new(attrs['sql'], target.split(':')[1])
          query.merge_hash_variables(doc.attributes, attrs)
          @report.logger.debug("from: #{query.from}, to: #{query.to}")

          begin
            reader.unshift_lines query.execute(@report.grafana(instance))
          rescue GrafanaReporterError => e
            @report.logger.error(e.message)
            reader.unshift_line '|' + e.message
          rescue StandardError => e
            @report.logger.fatal(e.message)
            reader.unshift_line '|' + e.message
          end

          reader
        end
      end
    end
  end
end
