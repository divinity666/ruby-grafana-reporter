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
        sql = attrs['sql']
        @report.logger.debug("Processing SqlValueInlineMacro (instance: #{instance}, datasource: #{target},"\
                             " sql: #{sql})")

        # translate sql statement to fix asciidoctor issue
        # refer https://github.com/asciidoctor/asciidoctor/issues/4072#issuecomment-991305715
        sql_translated = CGI::unescapeHTML(sql) if sql
        if sql != sql_translated
          @report.logger.debug("Translating SQL query to fix asciidoctor issue: #{sql_translated}")
          sql = sql_translated
        end

        begin
          # catch properly if datasource could not be identified
          query = QueryValueQuery.new(@report.grafana(instance),
                                      variables: build_attribute_hash(parent.document.attributes, attrs))
          query.datasource = @report.grafana(instance).datasource_by_id(target)
          query.raw_query = sql

          create_inline(parent, :quoted, query.execute)
        rescue Grafana::GrafanaError => e
          @report.logger.error(e.message)
          create_inline(parent, :quoted, e.message)
        rescue GrafanaReporterError => e
          @report.logger.error(e.message)
          create_inline(parent, :quoted, e.message)
        rescue StandardError => e
          @report.logger.fatal("#{e.message}\n#{e.backtrace.join("\n")}")
          create_inline(parent, :quoted, "#{e.message}\n#{e.backtrace.join("\n")}")
        end
      end

      # @see ProcessorMixin#build_demo_entry
      def build_demo_entry(panel)
        return nil unless panel
        return nil unless panel.model['targets']

        ref_id = nil
        panel.model['targets'].each do |item|
          if !item['hide'] && !panel.query(item['refId']).to_s.empty?
            ref_id = item['refId']
            break
          end
        end
        return nil unless ref_id
        # FIXME this filters out e.g. prometheus in demo reports, as the query method returns a Hash instead of a string
        return nil unless panel.query(ref_id).is_a?(String)

        "grafana_sql_value:#{panel.dashboard.grafana.datasource_by_model_entry(panel.model['datasource']).id}"\
        "[sql=\"#{panel.query(ref_id).gsub(/"/, '\"').gsub("\r\n", ' ').gsub("\n", ' ').gsub(/\\/, '\\\\')}\",from=\"now-1h\","\
        'to="now"]'
      end
    end
  end
end
