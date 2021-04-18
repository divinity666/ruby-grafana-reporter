# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
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
    # +format+ - see {AbstractQuery#format_columns}
    #
    # +replace_values+ - see {AbstractQuery#replace_values}
    #
    # +filter_columns+ - see {AbstractQuery#filter_columns}
    class SqlValueInlineMacro < ::Asciidoctor::Extensions::InlineMacroProcessor
      include ProcessorMixin
      use_dsl

      named :grafana_sql_value

      # @see GrafanaReporter::Asciidoctor::SqlFirstValueQuery
      def process(parent, target, attrs)
        return if @report.cancel

        @report.next_step
        instance = attrs['instance'] || parent.document.attr('grafana_default_instance') || 'default'
        attrs['result_type'] = 'sql_value'
        @report.logger.debug("Processing SqlValueInlineMacro (instance: #{instance}, datasource: #{target},"\
                             " sql: #{attrs['sql']})")

        begin
          # catch properly if datasource could not be identified
          query = QueryValueQuery.new(@report.grafana(instance))
          query.datasource = @report.grafana(instance).datasource_by_id(target)
          query.raw_query = attrs['sql']
          query.merge_hash_variables(parent.document.attributes, attrs)
          @report.logger.debug("from: #{query.from}, to: #{query.to}")

          create_inline(parent, :quoted, query.execute)
        rescue GrafanaReporterError => e
          @report.logger.error(e.message)
          create_inline(parent, :quoted, e.message)
        rescue StandardError => e
          @report.logger.fatal(e.message)
          create_inline(parent, :quoted, e.message)
        end
      end

      # @see ProcessorMixin#build_demo_entry
      def build_demo_entry(panel)
        return nil unless panel
        return nil unless panel.model['type'] == 'singlestat'

        ref_id = nil
        panel.model['targets'].each do |item|
          if !item['hide'] && !panel.query(item['refId']).to_s.empty?
            ref_id = item['refId']
            break
          end
        end
        return nil unless ref_id

        "grafana_sql_value:#{panel.dashboard.grafana.datasource_by_name(panel.model['datasource']).id}"\
        "[sql=\"#{panel.query(ref_id).gsub(/"/, '\"').gsub("\n", ' ').gsub(/\\/, '\\\\')}\",from=\"now-1h\","\
        'to="now"]'
      end
    end
  end
end
