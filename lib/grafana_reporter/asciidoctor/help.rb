# frozen_string_literal: true

require 'yaml'

module GrafanaReporter
  module Asciidoctor
    # This class generates the functional help documentation for the asciidoctor report.
    # It can create the documentation for github markdown, as well as in asciidoctor syntax.
    class Help
      # @param headline_level [Integer] top level of headline
      # @return [String] asciidoctor compatible documentation
      def asciidoctor(headline_level = 2)
        help_text(asciidoctor_options.merge(level: headline_level))
      end

      # @param headline_level [Integer] top level of headline
      # @return [String] github markdown compatible documentation
      def github(headline_level = 2)
        "#{toc}\n\n#{help_text(github_options.merge(level: headline_level))}"
      end

      private

      def github_options
        { headline_separator: '#', code_begin: '`', code_end: '`', table_begin: "\n", head_postfix_col: '| -- ' }
      end

      def asciidoctor_options
        { headline_separator: '=', code_begin: '`+', code_end: '+`', table_begin: "\n[%autowidth.stretch, "\
          "options=\"header\"]\n|===\n", table_end: "\n|===" }
      end

      def help_text(opts)
        %(#{opts[:headline_separator] * opts[:level]} Global options
#{global_options_as_text(opts.merge(level: opts[:level] + 1))}
#{opts[:headline_separator] * opts[:level]} Functions
#{functions_as_text(opts.merge(level: opts[:level] + 1))})
      end

      def toc
        result = []

        result << 'Table of contents'
        result << '* [Global options](#global-options)'
        prepared_help[:global_options].sort.map do |k, _v|
          result << "  * [#{k}](##{k.downcase})"
        end

        result << '* [Functions](#functions)'
        prepared_help[:functions].sort.map do |k, _v|
          result << "  * [#{k}](##{k.downcase})"
        end

        result.join("\n")
      end

      def global_options_as_text(opts = {})
        opts = { level: 3 }.merge(opts)
        result = []

        prepared_help[:global_options].sort.map do |k, v|
          result << %(
#{opts[:headline_separator] * opts[:level]} #{opts[:code_begin]}#{k}#{opts[:code_end]}
Usage: #{opts[:code_begin]}#{v['call']}#{opts[:code_end]}

#{v['description']}
)
        end

        result.join
      end

      def functions_as_text(opts = {})
        opts = { level: 3, headline_separator: '=' }.merge(opts)
        result = []

        prepared_help[:functions].sort.map do |k, v|
          result << %(
#{opts[:headline_separator] * opts[:level]} #{opts[:code_begin]}#{k}#{opts[:code_end]}
Usage: #{opts[:code_begin]}#{v[:call]}#{opts[:code_end]}

#{v[:description]}#{"\n\nSee also: #{v[:see]}" if v[:see]}#{unless v[:options].empty?
%(
#{opts[:table_begin]}| Option | Description#{"\n#{opts[:head_postfix_col] * 2}" if opts[:head_postfix_col]}
#{v[:options].sort.map { |_opt_k, opt_v| "| #{opts[:code_begin]}#{opt_v[:call]}#{opts[:code_end]} | #{opt_v[:description].gsub('|', '\|')}" }.join("\n") }#{opts[:table_end]})
end}
)
        end

        result.join
      end

      def prepared_help
        yaml = YAML.safe_load(raw_help_yaml)

        result = {}
        result[:functions] = {}
        result[:global_options] = yaml['global_options']

        functions = result[:functions]
        std_opts = yaml['standard_options']
        yaml.reject { |k, _v| k =~ /.*_options$/ }.each_key do |key|
          functions[key] = {}
          res_item = functions[key]
          res_item[:options] = {}

          item = yaml[key]
          res_item[:call] = item['call']
          res_item[:description] = item['description']
          res_item[:see] = item['see']

          opts = ((item['options'] ? item['options'].keys : [])
                  (item['standard_options'] ? item['standard_options'].keys : [])).sort
          opts.each do |opt_key|
            res_item[:options][opt_key] = {}

            if item['standard_options'].key?(opt_key)
              res_item[:options][opt_key][:call] = std_opts[opt_key]['call']
              res_item[:options][opt_key][:description] = "#{std_opts[opt_key]['description']} "\
                                                          "#{item['standard_options'][opt_key]}".chop
              res_item[:options][opt_key][:see] = std_opts[opt_key]['see'] if std_opts[opt_key]['see']
            else
              res_item[:options][opt_key][:call] = item['options'][opt_key]['call']
              res_item[:options][opt_key][:description] = item['options'][opt_key]['description']
              res_item[:options][opt_key][:see] = item['options'][opt_key]['see'] if item['options'][opt_key]['see']
            end
          end
        end

        result
      end

      def raw_help_yaml
        <<~YAML_HELP
          global_options:
            grafana_default_instance:
              call: ":grafana_default_instance: <instance_name>"
              description: >-
                Specifies which grafana instance shall be used. If not set, the grafana instance names `default`
                will be used.

            grafana_default_dashboard:
              call: ":grafana_default_dashboard: <dashboard_uid>"
              description: >-
                Specifies to which dashboard the queries shall be targeted by default.

            grafana_default_from_timezone:
              call: ":grafana_default_from_timezone: <timezone>"
              description: Specifies which timezone shall be used for the `from` time, e.g. `CET` or `CEST`.

            grafana_default_to_timezone:
              call: ":grafana_default_to_timezone: <timezone>"
              description: Specifies which timezone shall be used for the `to` time, e.g. `CET` or `CEST`.

            from:
              call: ":from: <from_timestamp>"
              description: >-
                Overrides the time setting from grafana. It may contain dates as `now-1M/M`, which will be translated
                properly to timestamps relative to the called time.

            to:
              call: ":to: <to_timestamp>"
              description: >-
                Overrides the time setting from grafana. It may contain dates as `now-1M/M`, which will be translated
                properly to timestamps relative to the called time.

          standard_options:
            instance:
              call: instance="<instance_name>"
              description: >-
                can be used to override global grafana instance, set in the report with `grafana_default_instance`.
                If nothing is set, the configured grafana instance with name `default` will be used.

            dashboard:
              call: dashboard="<dashboard_uid>"
              description: >-
                Specifies the dashboard to be used. If `grafana_default_dashboard` is specified in the report template,
                this value can be overridden with this option.

            from:
              call: from="<timestamp>"
              description: can be used to override default `from` time

            from_timezone:
              call: from_timezone="<timezone>"
              description: can be used to override system timezone for `from` time and will also override `grafana_default_from_timezone` option

            to_timezone:
              call: to_timezone="<timezone>"
              description: can be used to override system timezone for `to` time and will also override `grafana_default_to_timezone` option

            to:
              call: to="<timestamp>"
              description: can be used to override default `to` time

            format:
              call: format="<format_col1>,<format_col2>,..."
              description: >-
                Specify format in which the results shall be returned, e.g. `%.2f` for only two digit decimals of a
                float. Several columns are separated by `,`. Execution is applied in the following order `format`,
                `replace_values`, `filter_columns`, `transpose`.
              see: 'https://ruby-doc.org/core/Kernel.html#method-i-sprintf'

            replace_values:
              call: replace_values="<replace_1>:<with_1>,<replace_2>:<with_2>,..."
              description: >-
                Specify result values which shall be replaced, e.g. `2:OK` will replace query values `2` with value `OK`.
                Replacing several values is possible by separating by `,`. Matches with regular expressions are also
                supported, but must be full matches, i.e. have to start with `^` and end with `$`, e.g. `^[012]$:OK`.
                Number replacements can also be performed, e.g. `<8.2` or `<>3`. Execution is applied in the following order `format`,
                `replace_values`, `filter_columns`, `transpose`.
              see: https://ruby-doc.org/core/Regexp.html#class-Regexp-label-Character+Classes

            filter_columns:
              call: filter_columns="<column_name_1>,<column_name_2>,..."
              description: >-
                Removes specified columns from result. Execution is applied in the following order `format`, `replace_values`,
                `filter_columns`, `transpose`.

            transpose:
              call: transpose="true"
              description: >-
                Transposes the query result, i.e. columns become rows and rows become columnns. Execution is applied in the
                following order `format`, `replace_values`, `filter_columns`, `transpose`.

            column_divider:
              call: column_divider="<divider>"
              description: >-
                Replace the default column divider with another one, when used in conjunction with `table_formatter` set to
                `adoc_deprecated`. Defaults to ` | ` for being interpreted as a asciidoctor column. DEPRECATED: switch to
                `table_formatter` named `adoc_plain`, or implement a custom table formatter.

            row_divider:
              call: row_divider="<divider>"
              description: >-
                Replace the default row divider with another one, when used in conjunction with `table_formatter` set to
                `adoc_deprecated`. . Defaults to `| ` for being interpreted as a asciidoctor row. DEPRECATED: switch to
                `table_formatter` named `adoc_plain`, or implement a custom table formatter.

            table_formatter:
              call: table_formatter="<formatter>"
              description: >-
                Specify a table formatter fitting for your expected target format. It defaults to `adoc_plain` for asciidoctor
                templates and to `csv` for all other templates, e.g. ERB.

            timeout:
              call: timeout="<timeout_in_seconds>"
              description: >-
                Set a timeout for the current query. If not overridden with `grafana_default_timeout` in the report template,
                this defaults to 60 seconds.

          # ----------------------------------
          # FUNCTION DOCUMENTATION STARTS HERE
          # ----------------------------------

          grafana_help:
            description: Show all available grafana calls within the asciidoctor templates, including available options.
            call: 'include::grafana_help[]'

          grafana_environment:
            description: Shows all available variables in the rendering context which can be used in the asciidoctor template.
            call: 'include::grafana_environment[]'

          grafana_alerts:
            description: >-
              Returns a table of active alert states including the specified columns and the connected information. Supports
              all query parameters from the Grafana Alerting API, such as `query`, `state`, `limit`, `folderId` and others.
            call: 'include::grafana_alerts[columns="<column_name_1>,<column_name_2>,...",options]'
            see: https://grafana.com/docs/grafana/latest/http_api/alerting/#get-alerts
            options:
              columns:
                description: >-
                  Specifies columns that shall be returned. Valid columns are `id`, `dashboardId`, `dashboardUId`, `dashboardSlug`,
                  `panelId`, `name`, `state`, `newStateDate`, `evalDate`, `evalData` and `executionError`.
                call: columns="<column_name_1>,<columns_name_2>,..."
              panel:
                description: >-
                  If specified, the resulting alerts are filtered for this panel. This option will only work, if a `dashboard`
                  or `grafana_default_dashboard` is set.
                call: panel="<panel_id>"
            standard_options:
              column_divider:
              dashboard: >-
                If this option, or the global option `grafana_default_dashboard` is set, the resulting alerts will be limited to
                this dashboard. To show all alerts in this case, specify `dashboard=""` as option.
              filter_columns:
              format:
              from:
              instance:
              replace_values:
              row_divider:
              table_formatter:
              timeout:
              to:
              transpose:
              from_timezone:
              to_timezone:

          grafana_annotations:
            description: >-
              Returns a table of all annotations, matching the specified filter criteria and the specified columns. Supports all
              query parameters from the Grafana Alerting API, such as `limit`, `alertId`, `panelId` and others.
            call: 'include::grafana_annotations[columns="<column_name_1>,<column_name_2>,...",options]'
            see: https://grafana.com/docs/grafana/latest/http_api/annotations/#find-annotations
            options:
              columns:
                description: >-
                  Specified the columns that shall be returned. Valid columns are `id`, `alertId`, `dashboardId`, `panelId`, `userId`,
                  `userName`, `newState`, `prevState`, `time`, `timeEnd`, `text`, `metric` and `type`.
                call: columns="<column_name_1>,<columns_name_2>,..."
              panel:
                description: >-
                  If specified, the resulting alerts are filtered for this panel. This option will only work, if a `dashboard` or
                  `grafana_default_dashboard` is set.
                call: panel="<panel_id>"
            standard_options:
              column_divider:
              dashboard: >-
                If this option, or the global option `grafana_default_dashboard` is set, the resulting alerts will be limited to this
                dashboard. To show all alerts in this case, specify `dashboard=""` as option.
              filter_columns:
              format:
              from:
              instance:
              replace_values:
              row_divider:
              table_formatter:
              timeout:
              to:
              transpose:
              from_timezone:
              to_timezone:

          grafana_panel_property:
            description: >-
              Returns a property field for the specified panel. `<type>` can either be `title` or `description`.
              Grafana variables will be replaced in the returned value.
            call: 'grafana_panel_property:<panel_id>["<type>",options]'
            see: https://grafana.com/docs/grafana/latest/variables/syntax/
            standard_options:
              dashboard:
              instance:

          grafana_panel_image:
            description: Includes a panel image as an image in the document. Can be called for inline-images as well as for blocks.
            call: 'grafana_panel_image:<panel_id>[options] or grafana_panel_image::<panel_id>[options]'
            options:
              render-height:
                description: can be used to override default `height` in which the panel shall be rendered
                call: render-height="<height>"
              render-width:
                description: can be used to override default `width` in which the panel shall be rendered
                call: render-width="<width>"
              render-theme:
                description: can be used to override default `theme` in which the panel shall be rendered (light by default)
                call: render-theme="<theme>"
              render-timeout:
                description: can be used to override default `timeout` in which the panel shall be rendered (60 seconds by default)
                call: render-timeout="<timeout>"
            standard_options:
              dashboard:
              from:
              instance:
              timeout:
              to:
              from_timezone:
              to_timezone:

          grafana_panel_query_table:
            description: >-
              Returns the results of a query, which is configured in a grafana panel, as a table in asciidoctor.
              Grafana variables will be replaced in the panel's SQL statement.
            call: 'include::grafana_panel_query_table:<panel_id>[query="<query_letter>",options]'
            see: https://grafana.com/docs/grafana/latest/variables/syntax/
            options:
              query:
                call: query="<query_letter>"
                description: +<query_letter>+ needs to point to the grafana query which shall be evaluated, e.g. +A+ or +B+.
            standard_options:
              column_divider:
              dashboard:
              filter_columns:
              format:
              from:
              instance:
              replace_values:
              row_divider:
              table_formatter:
              timeout:
              to:
              transpose:
              from_timezone:
              to_timezone:

          grafana_panel_query_value:
            call: 'grafana_panel_query_value:<panel_id>[query="<query_letter>",options]'
            description: >-
              Returns the value in the first column and the first row of a query, which is configured in a grafana panel.
              Grafana variables will be replaced in the panel's SQL statement.
            see: https://grafana.com/docs/grafana/latest/variables/syntax/
            options:
              query:
                call: query="<query_letter>"
                description: +<query_letter>+ needs to point to the grafana query which shall be evaluated, e.g. +A+ or +B+.
            standard_options:
              dashboard:
              filter_columns:
              format:
              from:
              instance:
              replace_values:
              timeout:
              to:
              from_timezone:
              to_timezone:

          grafana_sql_table:
            call: 'include::grafana_sql_table:<datasource_id>[sql="<sql_query>",options]'
            description: >-
              Returns a table with all results of the given query.
              Grafana variables will be replaced in the SQL statement.
            see: https://grafana.com/docs/grafana/latest/variables/syntax/
            standard_options:
              column_divider:
              filter_columns:
              format:
              from:
              instance:
              replace_values:
              row_divider:
              table_formatter:
              timeout:
              to:
              transpose:
              from_timezone:
              to_timezone:

          grafana_sql_value:
            call: 'grafana_sql_value:<datasource_id>[sql="<sql_query>",options]'
            description: >-
              Returns the value in the first column and the first row of the given query.
              Grafana variables will be replaced in the SQL statement.
            see: https://grafana.com/docs/grafana/latest/variables/syntax/
            standard_options:
              filter_columns:
              format:
              from:
              instance:
              replace_values:
              timeout:
              to:
              from_timezone:
              to_timezone:
        YAML_HELP
      end
    end
  end
end
