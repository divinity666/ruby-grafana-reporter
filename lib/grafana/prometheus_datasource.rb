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

      url = if instant
        "/api/datasources/proxy/#{id}/api/v1/query?time=#{query_description[:to]}&query="\
        "#{CGI.escape(replace_variables(query, query_description[:variables]))}"
      else
        "/api/datasources/proxy/#{id}/api/v1/query_range?start=#{query_description[:from]}"\
        "&end=#{query_description[:to]}"\
        "&query=#{CGI.escape(replace_variables(query, query_description[:variables]))}"\
        "&step=#{interval}"
      end

      webrequest = query_description[:prepared_request]
      webrequest.relative_url = url
      webrequest.options.merge!({ request: Net::HTTP::Get })

      result = webrequest.execute(query_description[:timeout])
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

    # @see AbstractDatasource#preformat_response
    def preformat_response(response_body)
      json = {}
      begin
        json = JSON.parse(response_body)
      rescue
        raise UnsupportedQueryResponseReceivedError, response_body
      end

      # handle response with error result
      unless json['error'].nil?
        return { header: ['error'], content: [[ json['error'] ]] }
      end

      # handle dataframes
      if json['results']
        data = json['results'].values.first
        raise UnsupportedQueryResponseReceivedError, response_body if data.nil?
        raise UnsupportedQueryResponseReceivedError, response_body if data['frames'].nil?
        # TODO: check how multiple frames have to be handled

        data = data['frames']
        headers = []
        data.first['schema']['fields'].each do |headline|
          header = headline['config']['displayNameFromDS'].nil? ? headline['name'] : headline['config']['displayNameFromDS']
          headers << header
        end
        content = data.first['data']['values'][0].zip(data.first['data']['values'][1])
        return { header: headers, content: content }
      end

      # handle former result formats
      raise UnsupportedQueryResponseReceivedError, response_body if json['data'].nil?
      raise UnsupportedQueryResponseReceivedError, response_body if json['data']['resultType'].nil?
      raise UnsupportedQueryResponseReceivedError, response_body if json['data']['result'].nil?

      result_type = json['data']['resultType']
      json = json['data']['result']

      raise UnsupportedQueryResponseReceivedError, response_body if not result_type =~ /^(?:scalar|string|vector|matrix)$/

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

      { header: headers, content: content.to_a.map(&:flatten).sort { |a, b| a[0] <=> b[0] } }
    end
  end
end
