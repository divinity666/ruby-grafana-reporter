# frozen_string_literal: true

module Grafana
  # Implements the interface to Prometheus datasources.
  class InfluxDbDatasource < AbstractDatasource
    # @see AbstractDatasource#handles?
    def self.handles?(model)
      tmp = new(model)
      tmp.type == 'influxdb'
    end

    # +:database+ needs to contain the InfluxDb database name
    # +:raw_query+ needs to contain a InfluxDb query as String
    # @see AbstractDatasource#request
    def request(query_description)
      raise MissingSqlQueryError if query_description[:raw_query].nil?

      url = "/api/datasources/proxy/#{id}/query?db=#{@model['database']}&q=#{ERB::Util.url_encode(query_description[:raw_query])}&epoch=ms"

      webrequest = query_description[:prepared_request]
      webrequest.relative_url = url
      webrequest.options.merge!({ request: Net::HTTP::Get })

      result = webrequest.execute(query_description[:timeout])
      preformat_response(result.body)
    end

    # @see AbstractDatasource#raw_query_from_panel_model
    def raw_query_from_panel_model(panel_query_target)
      return panel_query_target['query'] if panel_query_target['rawQuery']

      # TODO: support composed queries
      raise ComposedQueryNotSupportedError, self
    end

    # @see AbstractDatasource#default_variable_format
    def default_variable_format
      'regex'
    end

    private

    # @see AbstractDatasource#preformat_response
    def preformat_response(response_body)
      # TODO: how to handle multiple query results?
      json = JSON.parse(response_body)['results'].first['series']

      header = ['time']
      content = {}

      # keep sorting, if json has only one target item, otherwise merge results and return
      # as a time sorted array
      return { header: header << "#{json.first['name']} #{json.first['columns'][1]} (#{json.first['tags']})", content: json.first['values'] } if json.length == 1

      # TODO: show warning here, as results may be sorted different
      json.each_index do |i|
        header << "#{json[i]['name']} #{json[i]['columns'][1]} (#{json[i]['tags']})"
        tmp = json[i]['values'].to_h
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
