# frozen_string_literal: true

module Grafana
  # Implements the interface to graphite datasources.
  class GraphiteDatasource < AbstractDatasource
    # @see AbstractDatasource#handles?
    def self.handles?(model)
      tmp = new(model)
      tmp.type == 'graphite'
    end

    # +:raw_query+ needs to contain a Graphite query as String
    # @see AbstractDatasource#request
    def request(query_description)
      raise MissingSqlQueryError if query_description[:raw_query].nil?

      request = {
        body: URI.encode_www_form('from': DateTime.strptime(query_description[:from], '%Q').strftime('%H:%M_%Y%m%d'),
                                  'until': DateTime.strptime(query_description[:to], '%Q').strftime('%H:%M_%Y%m%d'),
                                  'format': 'json',
                                  'target': replace_variables(query_description[:raw_query], query_description[:variables])),
        content_type: 'application/x-www-form-urlencoded',
        request: Net::HTTP::Post
      }

      webrequest = query_description[:prepared_request]
      webrequest.relative_url = "/api/datasources/proxy/#{id}/render"
      webrequest.options.merge!(request)

      result = webrequest.execute(query_description[:timeout])
      preformat_response(result.body)
    end

    # @see AbstractDatasource#raw_query_from_panel_model
    def raw_query_from_panel_model(panel_query_target)
      panel_query_target['target']
    end

    private

    # @see AbstractDatasource#preformat_response
    def preformat_response(response_body)
      json = JSON.parse(response_body)

      header = ['time']
      content = {}

      # keep sorting, if json has only one target item, otherwise merge results and return
      # as a time sorted array
      return { header: header << json.first['target'], content: json.first['datapoints'].map! { |item| [item[1], item[0]] } } if json.length == 1

      # TODO: show warning if results may be sorted different
      json.each_index do |i|
        header << json[i]['target']
        tmp = json[i]['datapoints'].map! { |item| [item[1], item[0]] }.to_h
        tmp.each_key { |key| content[key] = Array.new(json.length) unless content[key] }

        content.merge!(tmp) do |_key, old, new|
          old[i] = new
          old
        end
      end

      { header: header, content: content.to_a.map(&:flatten).sort { |a, b| a[0] <=> b[0] } }
    end
  end
end
