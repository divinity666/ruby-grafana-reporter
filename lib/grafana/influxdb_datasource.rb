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

      # replace variables
      query = replace_variables(query_description[:raw_query], query_description[:variables])

      # Unfortunately the grafana internal variables are not replaced in the grafana backend, but in the
      # frontend, i.e. we have to replace them here manually
      # replace $timeFilter variable
      query = query.gsub(/\$timeFilter(?=\W|$)/, "time >= #{query_description[:from]}ms and time <= #{query_description[:to]}ms")

      interval = query_description[:variables].delete('interval') || ((query_description[:to].to_i - query_description[:from].to_i) / 1000).to_i
      interval = interval.raw_value if interval.is_a?(Variable)

      # replace grafana variables $__interval and $__interval_ms in query
      # TODO: check where calculation and replacement of interval variable should take place
      query = query.gsub(/\$(?:__)?interval(?=\W|$)/, "#{interval.is_a?(String) ? interval : "#{(interval / 1000).to_i}s"}")
      query = query.gsub(/\$(?:__)?interval_ms(?=\W|$)/, "#{interval}")

      webrequest = query_description[:prepared_request]
      request = {}

      ver = query_description[:grafana_version].split('.').map{|x| x.to_i}
      if ver[0] >= 8
        webrequest.relative_url = "/api/ds/query?ds_type=influxdb"

        request = {
          request: Net::HTTP::Post,
          body: {
            from: query_description[:from],
            to: query_description[:to],
            queries: [
              {
                datasource: {type: "influxdb"},
                datasourceId: id,
                intervalMs: interval,
                query: query
              }
          ]}.to_json
        }
      else
        webrequest.relative_url = "/api/datasources/proxy/#{id}/query?db=#{@model['database']}&q=#{ERB::Util.url_encode(query)}&epoch=ms"
        request = {
          request: Net::HTTP::Get
        }
      end

      webrequest.options.merge!(request)


      result = webrequest.execute(query_description[:timeout])
      preformat_response(result.body)
    end

    # @see AbstractDatasource#raw_query_from_panel_model
    def raw_query_from_panel_model(panel_query_target)
      return panel_query_target['query'] if panel_query_target['query'] or panel_query_target['rawQuery']

      # build composed queries
      build_select(panel_query_target['select']) + build_from(panel_query_target) + build_where(panel_query_target['tags']) + build_group_by(panel_query_target['groupBy'])
    end

    # @see AbstractDatasource#default_variable_format
    def default_variable_format
      'regex'
    end

    private

    def build_group_by(stmt)
      groups = []
      fill = ""

      stmt.each do |group|
        case group['type']
        when 'tag'
          groups << "\"#{group['params'].first}\""

        when 'fill'
          fill = " fill(#{group['params'].first})"

        else
          groups << "#{group['type']}(#{group['params'].join(', ')})"

        end
      end

      " GROUP BY #{groups.join(', ')}#{fill}"
    end

    def build_where(stmt)
      custom_where = []

      stmt.each do |where|
        value = where['operator'] =~ /^[=!]~$/ ? where['value'] : "'#{where['value']}'"
        custom_where << "\"#{where['key']}\" #{where['operator']} #{value}"
      end

      " WHERE #{"(#{custom_where.join(' AND ')}) AND " unless custom_where.empty?}$timeFilter"
    end

    def build_from(stmt)
      " FROM \"#{"stmt['policy']." unless stmt['policy'] == 'default'}#{stmt['measurement']}\""
    end

    def build_select(stmt)
      res = "SELECT"
      parts = []

      stmt.each do |value|
        part = ""

        value.each do |item|
          case item['type']
          when 'field'
            # frame field parameter as string
            part = "\"#{item['params'].first}\""

          when 'alias'
            # append AS with parameter as string
            part = "#{part} AS \"#{item['params'].first}\""


          when 'math'
            # append parameter as raw value for calculation
            part = "#{part} #{item['params'].first}"


          else
            # frame current part by brackets and call by item function including parameters
            part = "#{item['type']}(#{part}#{", #{item['params'].join(', ')}" unless item['params'].empty?})"
          end
        end

        parts << part
      end

      "#{res} #{parts.join(', ')}"
    end

    def preformat_response(response_body)
      begin
        return preformat_dataframe_response(response_body)
      rescue
        # TODO: show an info, that the response if not a dataframe
      end

      # TODO: how to handle multiple query results?
      json = JSON.parse(response_body)
      json = json['results'].first['series']
      return {} if json.nil?

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

      return { header: header, content: content.to_a.map(&:flatten).sort { |a, b| a[0] <=> b[0] } }

    rescue
      raise UnsupportedQueryResponseReceivedError, response_body
    end
  end
end
