module GrafanaReporter
  module Asciidoctor
    module Extensions
      # Implements the hook
      #   include::grafana_help[]
      #
      # Shows all available options for the asciidoctor grafana reporter in a asciidoctor readable form.
      #
      # == Used document parameters
      # None
      class ShowHelpIncludeProcessor < ::Asciidoctor::Extensions::IncludeProcessor
        include ProcessorMixin

        # :nodoc:
        def handles?(target)
          target.start_with? 'grafana_help'
        end

        # :nodoc:
        def replaces_variables(where = nil)
          "https://grafana.com/docs/grafana/latest/variables/templates-and-variables/#variable-syntax[Grafana variables] will be replaced#{' ' + where.to_s if where}."
        end

        # :nodoc:
        def process(_doc, reader, _target, _attrs)
          # return if @report.cancel
          @report.next_step
          @report.logger.debug('Processing ShowHelpIncludeProcessor')

          param_instance = '| `instance="<instance_name>"` | can be used to override global grafana instance, set in the report with `grafana_default_instance`. If nothing is set, the configured grafana instance with name `default` will be used.'
          param_dashboard = '| `dashboard="<dashboard_uid>"` | Specifies the dashboard to be used. If `grafana_default_dashboard` is specified in the report template, this value can be overridden with this option.'
          param_from = '| `from="<from_timestamp>"` | can be used to override default `from` time'
          param_to = '| `to="<to_timestamp>"` | can be used to override default `to` time'
          param_format = '| `format="<format_col1>,<format_col2>,..."` | Specify format in which the results shall be returned, e.g. `%.2f` for only two digit decimals of a float. Several columns are separated by `,`. For details see https://ruby-doc.org/core-2.4.0/Kernel.html#method-i-sprintf[Ruby documentation]. This action is always performed *before* `replace_values`and `filter_columns`.'
          param_replace_values = '| `replace_values="<replace_1>:<with_1>,<replace_2>:<with_2>,..."` | Specify result values which shall be replaced, e.g. `2:OK` will replace query values `2` with value `OK`. Replacing several values is possible by separating by `,`. Matches with regular expressions are also supported, but must be full matches, i.e. have to start with `^` and end with `$`, e.g. `^[012]$:OK`. For details see https://ruby-doc.org/core-2.7.1/Regexp.html#class-Regexp-label-Character+Classes[Ruby Regexp class]. Number replacements can also be performed, e.g. `<8.2` or `<>3`. This action if always performed *after* `format`and *before* `filter_columns`.'
          param_filter_columns = '| `filter_columns="<column_name_1>,<column_name_2>,..."` | Removes specified columns from result. This action is always performed *after* `format` and `replace_values`.'

          help = "
== Grafana Reporter Functions
=== `grafana_help`
[cols=\"~,80\"]
|===
| Call | `+include::grafana_help[]+`
| Description | Shows this information.
|===

=== `grafana_environment`
[cols=\"~,80\"]
|===
| Call | `+include::grafana_environment[]+`
| Description | Shows all available variables in the rendering context which can be used in the document.
|===

=== `grafana_alerts`
[cols=\"~,80\"]
|===
| Call | `+grafana_alerts[columns=\"<column_name_1>,<column_name_2>,...\",options]+`
| Description | Returns a table of active alert states with the specified columns. Valid colums are `id`, `dashboardId`, `dashboardUId`, `dashboardSlug`, `panelId`, `name`, `state`, `newStateDate`, `evalDate`, `evalData` and `executionError` (for details see https://grafana.com/docs/grafana/latest/http_api/alerting/#get-alerts[Grafana Alerting API]).
|===
[%autowidth.stretch, options=\"header\"]
|===
| Option | Description
#{param_dashboard} If this option, or the global option `grafana_default_dashboard` is set, the resulting alerts will be limited to this dashboard. To show all alerts in this case, specify `dashboard=\"\"` as option.
#{param_filter_columns}
#{param_format}
#{param_from}
#{param_instance}
| `panel=\"<panel_id>\"` | If specified, the resulting alerts are filtered for this panel. This option will only work, if a `dashboard` or `grafana_default_dashboard` is set.
#{param_replace_values}
#{param_to}
|===
Additionally all query parameters from the https://grafana.com/docs/grafana/latest/http_api/alerting/#get-alerts[Grafana Alerting API], such as `query`, `state`, `limit`, `folderId` and others are supported.

=== `grafana_annotations`
[cols=\"~,80\"]
|===
| Call | `+grafana_annotations[columns=\"<column_name_1>,<column_name_2>,...\",options]+`
| Description | Returns a table of all annotations, matching the specified filter criteria and the specified columns. Valid colums are `id`, `alertId`, `dashboardId`, `panelId`, `userId`, `userName`, `newState`, `prevState, `time`, `timeEnd`, `text`, `metric` and `type` (for details see https://grafana.com/docs/grafana/latest/http_api/annotations/#find_annotations[Grafana Annotations API]).
|===
[%autowidth.stretch, options=\"header\"]
|===
| Option | Description
#{param_dashboard} If this option, or the global option `grafana_default_dashboard` is set, the resulting annotations will be limited to this dashboard. To show all annotations in this case, specify `dashboard=\"\"` as option.
#{param_filter_columns}
#{param_format}
#{param_from}
#{param_instance}
| `panel=\"<panel_id>\"` | If specified, the resulting annotations are filtered for this panel. This option will only work, if a `dashboard` or `grafana_default_dashboard` is set.
#{param_replace_values}
#{param_to}
|===
Additionally all quer parameters from the https://grafana.com/docs/grafana/latest/http_api/annotations/#find_annotations[Grafana Alerting API], such as `limit`, `alertId`, `panelId` and others are supported.

=== `grafana_panel_description`
[cols=\"~,80\"]
|===
| Call | `+grafana_panel_description:<panel_id>[\"<type>\",options]+`
| Description | Returns a description field for the specified panel. `+<type>+` can either be `title` or `description`. #{replaces_variables('in the returned value')}
|===
[%autowidth.stretch, options=\"header\"]
|===
| Option | Description
#{param_dashboard}
#{param_instance}
|===

=== `grafana_panel_image`
[cols=\"~,80\"]
|===
| Call Inline | `+grafana_panel_image:<panel_id>[options]+`
| Call Block | `+grafana_panel_image::<panel_id>[options]+`
| Description | Includes a panel image as an image in the document. Can be calles for inline-images as well as for blocks.
|===
[%autowidth.stretch, options=\"header\"]
|===
| Option | Description
#{param_dashboard}
#{param_from}
#{param_instance}
#{param_to}
| `render-height=\"<height>\"` | can be used to override default `height` in which the panel shall be rendered
| `render-width=\"<width>\"` | can be used to override default `width` in which the panel shall be rendered
| `render-theme=\"<theme>\"` | can be used to override default `theme` in which the panel shall be rendered (`light` by default)
| `render-timeout=\"<timeout>\"` | can be used to override default `timeout` in which the panel shall be rendered (60 seconds by default)
|===

=== `grafana_panel_query_table`
[cols=\"~,80\"]
|===
| Call | `+include:grafana_panel_query_table:<panel_id>[query=\"<query_letter>\",options]+`
| Description | Returns the results of a query, which is configured in a grafana panel, as a table in asciidoc. `+<query_letter>+` needs to point to the grafana query which shall be evaluated, e.g. `A` or `B`. #{replaces_variables("in the panel's SQL statement")}
|===
[%autowidth.stretch, options=\"header\"]
|===
| Option | Description
#{param_dashboard}
#{param_filter_columns}
#{param_format}
#{param_from}
#{param_instance}
#{param_replace_values}
#{param_to}
|===

=== `grafana_panel_query_value`
[cols=\"~,80\"]
|===
| Call | `+grafana_panel_query_value:<panel_id>[query=\"<query_letter>\",options]+`
| Description | Returns the first returned value of in the first column of  a query, which is configured in a grafana panel. `+<query_letter>+` needs to point to the grafana query which shall be evaluated, e.g. `A` or `B`. #{replaces_variables("in the panel's SQL statement")}
|===
[%autowidth.stretch, options=\"header\"]
|===
| Option | Description
#{param_dashboard}
#{param_filter_columns}
#{param_format}
#{param_from}
#{param_instance}
#{param_replace_values}
#{param_to}
|===

=== `grafana_sql_table`
[cols=\"~,80\"]
|===
| Call | `+include::grafana_sql_table:<datasource_id>[sql=\"<sql_query>\",options]+`
| Description | Returns a table with all results of the given query. #{replaces_variables('in the SQL statement')}
|===
[%autowidth.stretch, options=\"header\"]
|===
| Option | Description
#{param_filter_columns}
#{param_format}
#{param_from}
#{param_instance}
#{param_replace_values}
#{param_to}
|===

=== `grafana_sql_value`
[cols=\"~,80\"]
|===
| Call | `+grafana_sql_value:<datasource_id>[sql=\"<sql_query>\",options]+`
| Description | Returns a table with all results of the given query. #{replaces_variables('in the SQL statement')}
|===
[%autowidth.stretch, options=\"header\"]
|===
| Option | Description
#{param_filter_columns}
#{param_format}
#{param_from}
#{param_instance}
#{param_replace_values}
#{param_to}
|==="

          reader.unshift_lines help.split("\n")
        end
      end
    end
  end
end
