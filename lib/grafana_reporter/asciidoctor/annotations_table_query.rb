# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # This class is used to query annotations from grafana.
    class AnnotationsTableQuery < Grafana::AbstractQuery
      include QueryMixin

      # @option opts [Grafana::Dashboard] :dashboard dashboard, if annotations shall be filtered for a dashboard
      # @option opts [Grafana::Panel] :panel panel, if annotations shall be filtered for a panel
      def initialize(opts = {})
        super()

        @dashboard = opts[:dashboard]
        @panel = opts[:panel]
        @dashboard = @panel.dashboard if @panel

        extract_dashboard_variables(@dashboard) if @dashboard
      end

      # @return [String] URL for querying annotations
      def url
        "/api/annotations#{url_parameters}"
      end

      # @return [Hash] empty hash object
      def request
        {}
      end

      # Check if mandatory {Grafana::Variable} +columns+ is specified in variables.
      #
      # The value of the +columns+ variable has to be a comma separated list of column titles, which
      # need to be included in the following list:
      # - limit
      # - alertId
      # - userId
      # - type
      # - tags
      # - dashboardId
      # - panelId
      # @return [void]
      def pre_process(_grafana)
        raise MissingMandatoryAttributeError, 'columns' unless @variables['columns']

        @from = translate_date(@from, @variables['grafana-report-timestamp'], false, @variables['from_timezone'] ||
                               @variables['grafana_default_from_timezone'])
        @to = translate_date(@to, @variables['grafana-report-timestamp'], true, @variables['to_timezone'] ||
                             @variables['grafana_default_to_timezone'])
      end

      # Filters the query result for the given columns and sets the result
      # in the preformatted SQL result style.
      #
      # Additionally it applies {QueryMixin#format_columns}, {QueryMixin#replace_values} and
      # {QueryMixin#filter_columns}.
      # @return [void]
      def post_process
        # extract data from returned json
        result = JSON.parse(@result.body)
        content = []
        begin
          result.each { |item| content << item.fetch_values(*@variables['columns'].raw_value.split(',')) }
        rescue KeyError => e
          raise MalformedAttributeContentError.new(e.message, 'columns', @variables['columns'])
        end

        result = {}
        result[:header] = [@variables['columns'].raw_value.split(',')]
        result[:content] = content

        result = format_columns(result, @variables['format'])
        result = replace_values(result, @variables.select { |k, _v| k =~ /^replace_values_\d+/ })
        result = filter_columns(result, @variables['filter_columns'])

        @result = result[:content].map { |row| "| #{row.map { |item| item.to_s.gsub('|', '\\|') }.join(' | ')}" }
      end

      private

      def url_parameters
        url_vars = {}
        url_vars['dashboardId'] = ::Grafana::Variable.new(@dashboard.id) if @dashboard
        url_vars['panelId'] = ::Grafana::Variable.new(@panel.id) if @panel

        url_vars.merge!(variables.select { |k, _v| k =~ /^(?:limit|alertId|dashboardId|panelId|userId|type|tags)/ })
        url_vars['from'] = ::Grafana::Variable.new(@from) if @from
        url_vars['to'] = ::Grafana::Variable.new(@to) if @to
        url_params = URI.encode_www_form(url_vars.map { |k, v| [k, v.raw_value.to_s] })
        return '' if url_params.empty?

        "?#{url_params}"
      end
    end
  end
end
