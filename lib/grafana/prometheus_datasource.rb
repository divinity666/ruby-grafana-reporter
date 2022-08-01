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

      query_hash = query_description[:raw_query].is_a?(Hash) ? query_description[:raw_query] : {}

      # read instant value and convert instant value to boolean value
      instant = query_description[:variables].delete('instant') || query_hash[:instant] || false
      instant = instant.raw_value if instant.is_a?(Variable)
      instant = instant.to_s.downcase == 'true'
      interval = query_description[:variables].delete('interval') || query_hash[:interval] || 15
      interval = interval.raw_value if interval.is_a?(Variable)
      query = query_hash[:query] || query_description[:raw_query]

      ver = query_description[:grafana_version].split('.').map{|x| x.to_i}
      request = nil
      if (ver[0] == 7 and ver[1] < 5) or ver[0] < 7
        request = prepare_get_request({query_description: query_description, instant: instant, interval: interval, query: query})
      else
        request = prepare_post_request({query_description: query_description, instant: instant, interval: interval, query: query})
      end

      result = request.execute(query_description[:timeout])
      preformat_response(result.body)
    end

    # @see AbstractDatasource#raw_query_from_panel_model
    def raw_query_from_panel_model(panel_query_target)
      { query: panel_query_target['expr'], instant: panel_query_target['instant'],
        interval: panel_query_target['step'] }
    end

    # @see AbstractDatasource#default_variable_format
    def default_variable_format
        'regex'
    end

    private
    def prepare_get_request(hash)
      url = if hash[:instant]
        "/api/datasources/proxy/#{id}/api/v1/query?time=#{hash[:query_description][:to]}&query="\
        "#{CGI.escape(replace_variables(hash[:query], hash[:query_description][:variables]))}"
      else
        "/api/datasources/proxy/#{id}/api/v1/query_range?start=#{hash[:query_description][:from]}"\
        "&end=#{hash[:query_description][:to]}"\
        "&query=#{CGI.escape(replace_variables(hash[:query], hash[:query_description][:variables]))}"\
        "&step=#{hash[:interval]}"
      end

      webrequest = hash[:query_description][:prepared_request]
      webrequest.relative_url = url
      webrequest.options.merge!({ request: Net::HTTP::Get })

      webrequest
    end

    def prepare_post_request(hash)
      webrequest = hash[:query_description][:prepared_request]
      webrequest.relative_url = '/api/ds/query'

      params = {
        from: hash[:query_description][:from],
        to: hash[:query_description][:to],
        queries: [{
          datasource: { type: type, uid: uid },
          datasourceId: id,
          exemplar: false,
          expr: hash[:query],
          format: 'time_series',
          interval: '',
          # intervalFactor: ### 2,
          # intervalMs: ### 15000,
          # legendFormat: '', ### {{job}}
          # maxDataPoints: 999,
          metric: '',
          queryType: 'timeSeriesQuery',
          refId: 'A',
          # requestId: '14A',
          # utcOffsetSec: 7200,
          step: hash[:interval]
        }],
        range: {
          #from: ### "2022-07-31T16:19:26.198Z",
          #to: ### "2022-07-31T16:19:26.198Z",
          raw: { from: hash[:query_description][:variables]['from'].raw_value, to: hash[:query_description][:variables]['to'].raw_value }
        }
      }

      webrequest.options.merge!({ request: Net::HTTP::Post, body: params.to_json })

      webrequest
    end

    def preformat_response(response_body)
      # TODO: show raw response body to debug case https://github.com/divinity666/ruby-grafana-reporter/issues/24
      begin
        return preformat_dataframe_response(response_body)
      rescue
        # TODO: show an info, that the response is not a dataframe
      end

      json = JSON.parse(response_body)

      # handle response with error result
      unless json['error'].nil?
        return { header: ['error'], content: [[ json['error'] ]] }
      end

      # handle former result formats
      result_type = json['data']['resultType']
      json = json['data']['result']

      headers = ['time']
      content = {}

      # handle vector queries
      if result_type == 'vector'
        return {
          header: (headers << 'value') + json.first['metric'].keys,
          content: [ [json.first['value'][0], json.first['value'][1]] + json.first['metric'].values ]
        }
      end

      # handle scalar queries
      if result_type =~ /^(?:scalar|string)$/
        return { header: headers << result_type, content: [[json[0], json[1]]] }
      end

      # keep sorting, if json has only one target item, otherwise merge results and return
      # as a time sorted array
      if json.length == 1
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

      return { header: headers, content: content.to_a.map(&:flatten).sort { |a, b| a[0] <=> b[0] } }

    rescue
      raise UnsupportedQueryResponseReceivedError, response_body
    end
  end
end
