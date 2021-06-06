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

      url = "/api/datasources/proxy/#{id}/query?db=#{@model['database']}&q=#{URI.encode(query_description[:raw_query])}&epoch=ms"

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
      # TODO: specify default_variable_format for influx
      super
    end

    private

    # @see AbstractDatasource#preformat_response
    def preformat_response(response_body)
      json = JSON.parse(response_body)['results'].first['series']

      header = ['time']
      content = {}

      json.each_index do |i|
        # TODO support multiple columns
        header << "#{json[i]['name']} #{json[i]['columns'][1]} (#{json[i]['tags']})"
        tmp = json[i]['values'].to_h
        tmp.each_key { |key| content[key] = Array.new(json.length) unless content[key] }

        content.merge!(tmp) do |_key, old, new|
          old[i] = new
          old
        end
      end

      # TODO: ensure that sorting is identical to source sorting
      { header: header, content: content.to_a.map(&:flatten).sort { |a, b| a[0] <=> b[0] } }
    end
  end
end
