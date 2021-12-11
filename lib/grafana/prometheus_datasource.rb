# frozen_string_literal: true

module Grafana
  # Implements the interface to Prometheus datasources.
  class PrometheusDatasource < AbstractDatasource
    # @see AbstractDatasource#handles?
    def self.handles?(model)
      tmp = new(model)
      tmp.type == 'prometheus'
    end

    # +:raw_query+ needs to contain a Prometheus query as String
    # @see AbstractDatasource#request
    def request(query_description)
      raise MissingSqlQueryError if query_description[:raw_query].nil?

      # TODO: properly allow endpoint to be set - also check raw_query method
      end_point = @endpoint ? @endpoint : "query_range"

      # TODO: set query option 'step' on request
      url = "/api/datasources/proxy/#{id}/api/v1/#{end_point}?"\
            "start=#{query_description[:from]}&end=#{query_description[:to]}"\
            "&query=#{replace_variables(query_description[:raw_query], query_description[:variables])}"

      webrequest = query_description[:prepared_request]
      webrequest.relative_url = url
      webrequest.options.merge!({ request: Net::HTTP::Get })

      result = webrequest.execute(query_description[:timeout])
      preformat_response(result.body)
    end

    # @see AbstractDatasource#raw_query_from_panel_model
    def raw_query_from_panel_model(panel_query_target)
      @endpoint = panel_query_target['format'] == 'time_series' && (panel_query_target['instant'] == false || !panel_query_target['instant']) ? 'query_range' : 'query'
      panel_query_target['expr']
    end

    # @see AbstractDatasource#default_variable_format
    def default_variable_format
        'regex'
    end

    private

    # @see AbstractDatasource#preformat_response
    def preformat_response(response_body)
      json = JSON.parse(response_body)

      # handle response with error result
      unless json['error'].nil?
        return { header: ['error'], content: [[ json['error'] ]] }
      end

      json = json['data']['result']

      headers = ['time']
      content = {}

      # keep sorting, if json has only one target item, otherwise merge results and return
      # as a time sorted array
      # TODO properly set headlines
      if json.length == 1
        return { header: headers << json.first['metric'].to_s, content: [[json.first['value'][1], json.first['value'][0]]] } if json.first.has_key?('value') # this happens for the special case of calls to '/query' endpoint
        return { header: headers << json.first['metric']['mode'], content: json.first['values'] }
      end

      # TODO: show warning if results may be sorted different
      json.each_index do |i|
        headers += [json[i]['metric']['mode']]
        tmp = json[i]['values'].to_h
        tmp.each_key { |key| content[key] = Array.new(json.length) unless content[key] }

        content.merge!(tmp) do |_key, old, new|
          old[i] = new
          old
        end
      end

      { header: headers, content: content.to_a.map(&:flatten).sort { |a, b| a[0] <=> b[0] } }
    end
  end
end
