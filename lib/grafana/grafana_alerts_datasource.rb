# frozen_string_literal: true

module Grafana
  # Implements the datasource interface to grafana alerts.
  class GrafanaAlertsDatasource < AbstractDatasource
    # +:raw_query+ needs to contain a Hash with the following structure:
    #
    #   {
    #     dashboardId: Dashboard ID as String or nil
    #     panelId:     Panel ID as String or nil
    #     columns:
    #     limit:
    #     query:
    #     state:
    #     folderId:
    #     dashboardQuery:
    #     dashboardTag:
    #   }
    # @see AbstractDatasource#request
    def request(query_description)
      webrequest = query_description[:prepared_request]
      webrequest.relative_url = "/api/alerts#{url_parameters(query_description)}"

      result = webrequest.execute(query_description[:timeout])

      json = JSON.parse(result.body)

      content = []
      begin
        json.each { |item| content << item.fetch_values(*query_description[:raw_query]['columns'].split(',')) }
      rescue KeyError => e
        raise MalformedAttributeContentError.new(e.message, 'columns', query_description[:raw_query]['columns'])
      end

      result = {}
      result[:header] = [query_description[:raw_query]['columns'].split(',')]
      result[:content] = content

      result
    end

    private

    def url_parameters(query_desc)
      url_vars = {}
      url_vars.merge!(query_desc[:raw_query].select do |k, _v|
        k =~ /^(?:limit|dashboardId|panelId|query|state|folderId|dashboardQuery|dashboardTag)/
      end)
      url_vars['from'] = query_desc[:from] if query_desc[:from]
      url_vars['to'] = query_desc[:to] if query_desc[:to]
      url_params = URI.encode_www_form(url_vars.map { |k, v| [k, v.to_s] })
      return '' if url_params.empty?

      "?#{url_params}"
    end
  end
end
