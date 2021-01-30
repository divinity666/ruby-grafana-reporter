Table of contents
* [Global options](#global-options)
  * [from](#from)
  * [grafana_default_dashboard](#grafana_default_dashboard)
  * [grafana_default_from_timezone](#grafana_default_from_timezone)
  * [grafana_default_instance](#grafana_default_instance)
  * [grafana_default_to_timezone](#grafana_default_to_timezone)
  * [to](#to)
* [Functions](#functions)
  * [grafana_alerts](#grafana_alerts)
  * [grafana_annotations](#grafana_annotations)
  * [grafana_environment](#grafana_environment)
  * [grafana_help](#grafana_help)
  * [grafana_panel_description](#grafana_panel_description)
  * [grafana_panel_image](#grafana_panel_image)
  * [grafana_panel_query_table](#grafana_panel_query_table)
  * [grafana_panel_query_value](#grafana_panel_query_value)
  * [grafana_sql_table](#grafana_sql_table)
  * [grafana_sql_value](#grafana_sql_value)

## Global options

### `from`
Usage: `:from: <from_timestamp>`

Overrides the time setting from grafana. It may contain dates as `now-1M/M`, which will be translated properly to timestamps relative to the called time.

### `grafana_default_dashboard`
Usage: `:grafana_default_dashboard: <dashboard_uid>`

Specifies to which dashboard the queries shall be targeted by default.

### `grafana_default_from_timezone`
Usage: `:grafana_default_from_timezone: <timezone>`

Specifies which timezone shall be used for the `from` time, e.g. `CET` or `CEST`.

### `grafana_default_instance`
Usage: `:grafana_default_instance: <instance_name>`

Specifies which grafana instance shall be used. If not set, the grafana instance names `default` will be used.

### `grafana_default_to_timezone`
Usage: `:grafana_default_to_timezone: <timezone>`

Specifies which timezone shall be used for the `to` time, e.g. `CET` or `CEST`.

### `to`
Usage: `:to: <to_timestamp>`

Overrides the time setting from grafana. It may contain dates as `now-1M/M`, which will be translated properly to timestamps relative to the called time.

## Functions

### `grafana_alerts`
Usage: `grafana_alerts[columns="<column_name_1>,<column_name_2>,...",options]`

Returns a table of active alert states including the specified columns and the connected information. Supports all query parameters from the Grafana Alerting API, such as `query`, `state`, `limit`, `folderId` and others.

See also: https://grafana.com/docs/grafana/latest/http_api/alerting/#get-alerts

| Option | Description
| -- | -- 
| `column_divider="<divider>"` | Replace the default column divider with another one. Defaults to ` \| ` for being interpreted as a asciidoctor column.
| `columns="<column_name_1>,<columns_name_2>,..."` | Specifies columns that shall be returned. Valid columns are `id`, `dashboardId`, `dashboardUId`, `dashboardSlug`, `panelId`, `name`, `state`, `newStateDate`, `evalDate`, `evalData` and `executionError`.
| `dashboard="<dashboard_uid>"` | Specifies the dashboard to be used. If `grafana_default_dashboard` is specified in the report template, this value can be overridden with this option. If this option, or the global option `grafana_default_dashboard` is set, the resulting alerts will be limited to this dashboard. To show all alerts in this case, specify `dashboard=""` as option
| `filter_columns="<column_name_1>,<column_name_2>,..."` | Removes specified columns from result. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `format="<format_col1>,<format_col2>,..."` | Specify format in which the results shall be returned, e.g. `%.2f` for only two digit decimals of a float. Several columns are separated by `,`. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `from="<timestamp>"` | can be used to override default `from` time
| `from_timezone="<timezone>"` | can be used to override system timezone for `from` time and will also override `grafana_default_from_timezone` option
| `instance="<instance_name>"` | can be used to override global grafana instance, set in the report with `grafana_default_instance`. If nothing is set, the configured grafana instance with name `default` will be used.
| `panel="<panel_id>"` | If specified, the resulting alerts are filtered for this panel. This option will only work, if a `dashboard` or `grafana_default_dashboard` is set.
| `replace_values="<replace_1>:<with_1>,<replace_2>:<with_2>,..."` | Specify result values which shall be replaced, e.g. `2:OK` will replace query values `2` with value `OK`. Replacing several values is possible by separating by `,`. Matches with regular expressions are also supported, but must be full matches, i.e. have to start with `^` and end with `$`, e.g. `^[012]$:OK`. Number replacements can also be performed, e.g. `<8.2` or `<>3`. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `row_divider="<divider>"` | Replace the default row divider with another one. Defaults to `\| ` for being interpreted as a asciidoctor row.
| `timeout="<timeout_in_seconds>"` | Set a timeout for the current query. If not overridden with `grafana-default-timeout` in the report template, this defaults to 60 seconds.
| `to="<timestamp>"` | can be used to override default `to` time
| `to_timezone="<timezone>"` | can be used to override system timezone for `to` time and will also override `grafana_default_to_timezone` option
| `transpose="true"` | Transposes the query result, i.e. columns become rows and rows become columnns. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.

### `grafana_annotations`
Usage: `grafana_annotations[columns="<column_name_1>,<column_name_2>,...",options]`

Returns a table of all annotations, matching the specified filter criteria and the specified columns. Supports all query parameters from the Grafana Alerting API, such as `limit`, `alertId`, `panelId` and others.

See also: https://grafana.com/docs/grafana/latest/http_api/annotations/#find_annotations

| Option | Description
| -- | -- 
| `column_divider="<divider>"` | Replace the default column divider with another one. Defaults to ` \| ` for being interpreted as a asciidoctor column.
| `columns="<column_name_1>,<columns_name_2>,..."` | Specified the columns that shall be returned. Valid columns are `id`, `alertId`, `dashboardId`, `panelId`, `userId`, `userName`, `newState`, `prevState, `time`, `timeEnd`, `text`, `metric` and `type`.
| `dashboard="<dashboard_uid>"` | Specifies the dashboard to be used. If `grafana_default_dashboard` is specified in the report template, this value can be overridden with this option. If this option, or the global option `grafana_default_dashboard` is set, the resulting alerts will be limited to this dashboard. To show all alerts in this case, specify `dashboard=""` as option
| `filter_columns="<column_name_1>,<column_name_2>,..."` | Removes specified columns from result. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `format="<format_col1>,<format_col2>,..."` | Specify format in which the results shall be returned, e.g. `%.2f` for only two digit decimals of a float. Several columns are separated by `,`. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `from="<timestamp>"` | can be used to override default `from` time
| `from_timezone="<timezone>"` | can be used to override system timezone for `from` time and will also override `grafana_default_from_timezone` option
| `instance="<instance_name>"` | can be used to override global grafana instance, set in the report with `grafana_default_instance`. If nothing is set, the configured grafana instance with name `default` will be used.
| `panel="<panel_id>"` | If specified, the resulting alerts are filtered for this panel. This option will only work, if a `dashboard` or `grafana_default_dashboard` is set.
| `replace_values="<replace_1>:<with_1>,<replace_2>:<with_2>,..."` | Specify result values which shall be replaced, e.g. `2:OK` will replace query values `2` with value `OK`. Replacing several values is possible by separating by `,`. Matches with regular expressions are also supported, but must be full matches, i.e. have to start with `^` and end with `$`, e.g. `^[012]$:OK`. Number replacements can also be performed, e.g. `<8.2` or `<>3`. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `row_divider="<divider>"` | Replace the default row divider with another one. Defaults to `\| ` for being interpreted as a asciidoctor row.
| `timeout="<timeout_in_seconds>"` | Set a timeout for the current query. If not overridden with `grafana-default-timeout` in the report template, this defaults to 60 seconds.
| `to="<timestamp>"` | can be used to override default `to` time
| `to_timezone="<timezone>"` | can be used to override system timezone for `to` time and will also override `grafana_default_to_timezone` option
| `transpose="true"` | Transposes the query result, i.e. columns become rows and rows become columnns. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.

### `grafana_environment`
Usage: `include::grafana_environment[]`

Shows all available variables in the rendering context which can be used in the asciidoctor template.

### `grafana_help`
Usage: `include::grafana_help[]`

Show all available grafana calls within the asciidoctor templates, including available options.

### `grafana_panel_description`
Usage: `grafana_panel_description:<panel_id>["<type>",options]`

Returns a description field for the specified panel. `<type>` can either be `title` or `description`. Grafana variables will be replaced in the returned value.

See also: https://grafana.com/docs/grafana/latest/variables/templates-and-variables/#variable-syntax

| Option | Description
| -- | -- 
| `dashboard="<dashboard_uid>"` | Specifies the dashboard to be used. If `grafana_default_dashboard` is specified in the report template, this value can be overridden with this option.
| `instance="<instance_name>"` | can be used to override global grafana instance, set in the report with `grafana_default_instance`. If nothing is set, the configured grafana instance with name `default` will be used.

### `grafana_panel_image`
Usage: `grafana_panel_image:<panel_id>[options] or grafana_panel_image::<panel_id>[options]`

Includes a panel image as an image in the document. Can be called for inline-images as well as for blocks.

| Option | Description
| -- | -- 
| `dashboard="<dashboard_uid>"` | Specifies the dashboard to be used. If `grafana_default_dashboard` is specified in the report template, this value can be overridden with this option.
| `from="<timestamp>"` | can be used to override default `from` time
| `from_timezone="<timezone>"` | can be used to override system timezone for `from` time and will also override `grafana_default_from_timezone` option
| `instance="<instance_name>"` | can be used to override global grafana instance, set in the report with `grafana_default_instance`. If nothing is set, the configured grafana instance with name `default` will be used.
| `render-height="<height>"` | can be used to override default `height` in which the panel shall be rendered
| `render-theme="<theme>"` | can be used to override default `theme` in which the panel shall be rendered (light by default)
| `render-timeout="<timeout>"` | can be used to override default `timeout` in which the panel shall be rendered (60 seconds by default)
| `render-width="<width>"` | can be used to override default `width` in which the panel shall be rendered
| `timeout="<timeout_in_seconds>"` | Set a timeout for the current query. If not overridden with `grafana-default-timeout` in the report template, this defaults to 60 seconds.
| `to="<timestamp>"` | can be used to override default `to` time
| `to_timezone="<timezone>"` | can be used to override system timezone for `to` time and will also override `grafana_default_to_timezone` option

### `grafana_panel_query_table`
Usage: `include::grafana_panel_query_table:<panel_id>[query="<query_letter>",options]`

Returns the results of a query, which is configured in a grafana panel, as a table in asciidoctor. Grafana variables will be replaced in the panel's SQL statement.

See also: https://grafana.com/docs/grafana/latest/variables/templates-and-variables/#variable-syntax

| Option | Description
| -- | -- 
| `column_divider="<divider>"` | Replace the default column divider with another one. Defaults to ` \| ` for being interpreted as a asciidoctor column.
| `dashboard="<dashboard_uid>"` | Specifies the dashboard to be used. If `grafana_default_dashboard` is specified in the report template, this value can be overridden with this option.
| `filter_columns="<column_name_1>,<column_name_2>,..."` | Removes specified columns from result. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `format="<format_col1>,<format_col2>,..."` | Specify format in which the results shall be returned, e.g. `%.2f` for only two digit decimals of a float. Several columns are separated by `,`. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `from="<timestamp>"` | can be used to override default `from` time
| `from_timezone="<timezone>"` | can be used to override system timezone for `from` time and will also override `grafana_default_from_timezone` option
| `instance="<instance_name>"` | can be used to override global grafana instance, set in the report with `grafana_default_instance`. If nothing is set, the configured grafana instance with name `default` will be used.
| `query="<query_letter>"` | +<query_letter>+ needs to point to the grafana query which shall be evaluated, e.g. +A+ or +B+.
| `replace_values="<replace_1>:<with_1>,<replace_2>:<with_2>,..."` | Specify result values which shall be replaced, e.g. `2:OK` will replace query values `2` with value `OK`. Replacing several values is possible by separating by `,`. Matches with regular expressions are also supported, but must be full matches, i.e. have to start with `^` and end with `$`, e.g. `^[012]$:OK`. Number replacements can also be performed, e.g. `<8.2` or `<>3`. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `row_divider="<divider>"` | Replace the default row divider with another one. Defaults to `\| ` for being interpreted as a asciidoctor row.
| `timeout="<timeout_in_seconds>"` | Set a timeout for the current query. If not overridden with `grafana-default-timeout` in the report template, this defaults to 60 seconds.
| `to="<timestamp>"` | can be used to override default `to` time
| `to_timezone="<timezone>"` | can be used to override system timezone for `to` time and will also override `grafana_default_to_timezone` option
| `transpose="true"` | Transposes the query result, i.e. columns become rows and rows become columnns. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.

### `grafana_panel_query_value`
Usage: `grafana_panel_query_value:<panel_id>[query="<query_letter>",options]`

Returns the value in the first column and the first row of a query, which is configured in a grafana panel. Grafana variables will be replaced in the panel's SQL statement.

See also: https://grafana.com/docs/grafana/latest/variables/templates-and-variables/#variable-syntax

| Option | Description
| -- | -- 
| `dashboard="<dashboard_uid>"` | Specifies the dashboard to be used. If `grafana_default_dashboard` is specified in the report template, this value can be overridden with this option.
| `filter_columns="<column_name_1>,<column_name_2>,..."` | Removes specified columns from result. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `format="<format_col1>,<format_col2>,..."` | Specify format in which the results shall be returned, e.g. `%.2f` for only two digit decimals of a float. Several columns are separated by `,`. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `from="<timestamp>"` | can be used to override default `from` time
| `from_timezone="<timezone>"` | can be used to override system timezone for `from` time and will also override `grafana_default_from_timezone` option
| `instance="<instance_name>"` | can be used to override global grafana instance, set in the report with `grafana_default_instance`. If nothing is set, the configured grafana instance with name `default` will be used.
| `query="<query_letter>"` | +<query_letter>+ needs to point to the grafana query which shall be evaluated, e.g. +A+ or +B+.
| `replace_values="<replace_1>:<with_1>,<replace_2>:<with_2>,..."` | Specify result values which shall be replaced, e.g. `2:OK` will replace query values `2` with value `OK`. Replacing several values is possible by separating by `,`. Matches with regular expressions are also supported, but must be full matches, i.e. have to start with `^` and end with `$`, e.g. `^[012]$:OK`. Number replacements can also be performed, e.g. `<8.2` or `<>3`. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `timeout="<timeout_in_seconds>"` | Set a timeout for the current query. If not overridden with `grafana-default-timeout` in the report template, this defaults to 60 seconds.
| `to="<timestamp>"` | can be used to override default `to` time
| `to_timezone="<timezone>"` | can be used to override system timezone for `to` time and will also override `grafana_default_to_timezone` option

### `grafana_sql_table`
Usage: `include::grafana_sql_table:<datasource_id>[sql="<sql_query>",options]`

Returns a table with all results of the given query. Grafana variables will be replaced in the SQL statement.

See also: https://grafana.com/docs/grafana/latest/variables/templates-and-variables/#variable-syntax

| Option | Description
| -- | -- 
| `column_divider="<divider>"` | Replace the default column divider with another one. Defaults to ` \| ` for being interpreted as a asciidoctor column.
| `filter_columns="<column_name_1>,<column_name_2>,..."` | Removes specified columns from result. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `format="<format_col1>,<format_col2>,..."` | Specify format in which the results shall be returned, e.g. `%.2f` for only two digit decimals of a float. Several columns are separated by `,`. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `from="<timestamp>"` | can be used to override default `from` time
| `from_timezone="<timezone>"` | can be used to override system timezone for `from` time and will also override `grafana_default_from_timezone` option
| `instance="<instance_name>"` | can be used to override global grafana instance, set in the report with `grafana_default_instance`. If nothing is set, the configured grafana instance with name `default` will be used.
| `replace_values="<replace_1>:<with_1>,<replace_2>:<with_2>,..."` | Specify result values which shall be replaced, e.g. `2:OK` will replace query values `2` with value `OK`. Replacing several values is possible by separating by `,`. Matches with regular expressions are also supported, but must be full matches, i.e. have to start with `^` and end with `$`, e.g. `^[012]$:OK`. Number replacements can also be performed, e.g. `<8.2` or `<>3`. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `row_divider="<divider>"` | Replace the default row divider with another one. Defaults to `\| ` for being interpreted as a asciidoctor row.
| `timeout="<timeout_in_seconds>"` | Set a timeout for the current query. If not overridden with `grafana-default-timeout` in the report template, this defaults to 60 seconds.
| `to="<timestamp>"` | can be used to override default `to` time
| `to_timezone="<timezone>"` | can be used to override system timezone for `to` time and will also override `grafana_default_to_timezone` option
| `transpose="true"` | Transposes the query result, i.e. columns become rows and rows become columnns. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.

### `grafana_sql_value`
Usage: `grafana_sql_value:<datasource_id>[sql="<sql_query>",options]`

Returns the value in the first column and the first row of the given query. Grafana variables will be replaced in the SQL statement.

See also: https://grafana.com/docs/grafana/latest/variables/templates-and-variables/#variable-syntax

| Option | Description
| -- | -- 
| `filter_columns="<column_name_1>,<column_name_2>,..."` | Removes specified columns from result. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `format="<format_col1>,<format_col2>,..."` | Specify format in which the results shall be returned, e.g. `%.2f` for only two digit decimals of a float. Several columns are separated by `,`. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `from="<timestamp>"` | can be used to override default `from` time
| `from_timezone="<timezone>"` | can be used to override system timezone for `from` time and will also override `grafana_default_from_timezone` option
| `instance="<instance_name>"` | can be used to override global grafana instance, set in the report with `grafana_default_instance`. If nothing is set, the configured grafana instance with name `default` will be used.
| `replace_values="<replace_1>:<with_1>,<replace_2>:<with_2>,..."` | Specify result values which shall be replaced, e.g. `2:OK` will replace query values `2` with value `OK`. Replacing several values is possible by separating by `,`. Matches with regular expressions are also supported, but must be full matches, i.e. have to start with `^` and end with `$`, e.g. `^[012]$:OK`. Number replacements can also be performed, e.g. `<8.2` or `<>3`. Execution is applied in the following order `format`, `replace_values`, `filter_columns`, `transpose`.
| `timeout="<timeout_in_seconds>"` | Set a timeout for the current query. If not overridden with `grafana-default-timeout` in the report template, this defaults to 60 seconds.
| `to="<timestamp>"` | can be used to override default `to` time
| `to_timezone="<timezone>"` | can be used to override system timezone for `to` time and will also override `grafana_default_to_timezone` option
