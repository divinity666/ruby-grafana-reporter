module GrafanaReporter

  module Asciidoctor
    module Extensions

      # Implements the hook
      #   grafana_sql_value:<datasource_id>[<options>]
      #
      # Returns the first value of the resulting SQL query.
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
      class SqlValueInlineMacro < ::Asciidoctor::Extensions::InlineMacroProcessor
        include ProcessorMixin
        use_dsl

        named :grafana_sql_value

        # @see GrafanaReporter::Asciidoctor::SqlFirstValueQuery
        def process(parent, target, attrs)
          return if @report.cancel

          @report.next_step
          instance = attrs['instance'] || parent.document.attr('grafana_default_instance') || 'default'
          @report.logger.debug("Processing SqlValueInlineMacro (instance: #{instance}, datasource: #{target}, sql: #{attrs['sql']})")
          query = SqlFirstValueQuery.new(attrs['sql'], target)
          query.merge_hash_variables(parent.document.attributes, attrs)
          @report.logger.debug("from: #{query.from}, to: #{query.to}")

          begin
            create_inline(parent, :quoted, query.execute(@report.grafana(instance)))
          rescue GrafanaReporterError => e
            @report.logger.error(e.message)
            create_inline(parent, :quoted, e.message)
          rescue StandardError => e
            @report.logger.fatal(e.message)
            create_inline(parent, :quoted, e.message)
          end
        end
      end
    end
  end
end
