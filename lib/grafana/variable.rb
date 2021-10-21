# frozen_string_literal: true

module Grafana
  # This class contains a representation of
  # {https://grafana.com/docs/grafana/latest/variables/templates-and-variables grafana variables},
  # aka grafana templates.
  #
  # The main need therefore rises in order to replace variables properly in different
  # texts, e.g. SQL statements or results.
  class Variable
    attr_reader :name, :text, :raw_value

    # Translation table to support {https://momentjs.com/docs/#/displaying/}.
    DATE_MATCHES = { 'M' => '%-m', 'MM' => '%m', 'MMM' => '%b',  'MMMM' => '%B',
                     'D' => '%-d', 'DD' => '%d', 'DDD' => '%-j', 'DDDD' => '%j',
                     'd' => '%w',                'ddd' => '%a',  'dddd' => '%A',
                     'YY' => '%y', 'YYYY' => '%Y',
                     'h' => '%-I', 'hh' => '%I',
                     'H' => '%-H', 'HH' => '%H',
                     'm' => '%-M', 'mm' => '%M',
                     's' => '%-S', 'ss' => '%S',
                     'w' => '%-U', 'ww' => '%U',
                     'W' => '%-V', 'WW' => '%V',
                     'a' => '%P',
                     'A' => '%p',
                     'e' => '%w',
                     'E' => '%u',
                     'X' => '%s' }.freeze

    # @param config_or_value [Hash, Object] configuration hash of a variable out of an {Dashboard} instance
    #  or a value of any kind.
    # @param dashboard [Dashboard] parent dashboard, if applicable; especially needed for query variable
    #  evaluation.
    def initialize(config_or_value, dashboard = nil)
      if config_or_value.is_a? Hash
        @dashboard = dashboard
        @config = config_or_value
        @name = @config['name']
        init_values
      else
        @config = {}
        @raw_value = config_or_value
        @text = config_or_value.to_s
      end
    end

    # Returns the stored value formatted according the given format.
    #
    # Supported formats are: +csv+, +distributed+, +doublequote+, +json+, +percentencode+, +pipe+, +raw+,
    # +regex+, +singlequote+, +sqlstring+, +lucene+, +date+ or +glob+ (default)
    #
    # For details see {https://grafana.com/docs/grafana/latest/variables/advanced-variable-format-options
    # Grafana Advanced variable format options}.
    #
    # For details of +date+ format, see
    # {https://grafana.com/docs/grafana/latest/variables/variable-types/global-variables/#__from-and-__to
    # Grafana global variables $__from and $__to}.
    # Please note that input for +date+ format is unixtime in milliseconds.
    #
    # @param format [String] desired format
    # @return [String] value of stored variable according the specified format
    def value_formatted(format = '')
      value = @raw_value

      # if 'All' is selected for this template variable, capture all values properly
      # (from grafana config or query) and format the results afterwards accordingly
      if value == '$__all'
        if !@config['options'].empty?
          # this query contains predefined values, so capture them and format the values accordingly
          # this happens either for type='custom' or type 'query', if it is never updated
          value = @config['options'].reject { |item| item['value'] == '$__all' }.map { |item| item['value'] }

        elsif @config['type'] == 'query' && !@config['query'].empty?
          # variables in this configuration are not stored in grafana, i.e. if all is selected here,
          # the values have to be fetched from the datasource
          query = ::GrafanaReporter::QueryValueQuery.new(@dashboard)
          query.datasource = @dashboard.grafana.datasource_by_name(@config['datasource'])
          query.variables['result_type'] = Variable.new('object')
          query.raw_query = @config['query']
          result = query.execute

          value = result[:content].map { |item| item[0].to_s }

        else
          # TODO: add support for variable type: 'datasource' and 'adhoc'
        end
      end

      case format
      when 'csv'
        return value.join(',').to_s if multi? && value.is_a?(Array)

        value.to_s

      when 'distributed'
        return value.join(",#{name}=") if multi? && value.is_a?(Array)

        value
      when 'doublequote'
        if multi? && value.is_a?(Array)
          value = value.map { |item| "\"#{item.gsub(/\\/, '\\\\').gsub(/"/, '\\"')}\"" }
          return value.join(',')
        end
        "\"#{value.gsub(/"/, '\\"')}\""

      when 'json'
        if multi? && value.is_a?(Array)
          value = value.map { |item| "\"#{item.gsub(/["\\]/, '\\\\\0')}\"" }
          return "[#{value.join(',')}]"
        end
        "\"#{value.gsub(/"/, '\\"')}\""

      when 'percentencode'
        value = "{#{value.join(',')}}" if multi? && value.is_a?(Array)
        ERB::Util.url_encode(value)

      when 'pipe'
        return value.join('|') if multi? && value.is_a?(Array)

        value

      when 'raw'
        return "{#{value.join(',')}}" if multi? && value.is_a?(Array)

        value

      when 'regex'
        if multi? && value.is_a?(Array)
          value = value.map { |item| item.gsub(%r{[/$.|\\]}, '\\\\\0') }
          return "(#{value.join('|')})"
        end
        value.gsub(%r{[/$.|\\]}, '\\\\\0')

      when 'singlequote'
        if multi? && value.is_a?(Array)
          value = value.map { |item| "'#{item.gsub(/'/, '\\\\\0')}'" }
          return value.join(',')
        end
        "'#{value.gsub(/'/, '\\\\\0')}'"

      when 'sqlstring'
        if multi? && value.is_a?(Array)
          value = value.map { |item| "'#{item.gsub(/'/, "''")}'" }
          return value.join(',')
        end
        "'#{value.gsub(/'/, "''")}'"

      when 'lucene'
        if multi? && value.is_a?(Array)
          value = value.map { |item| "\"#{item.gsub(%r{[" |=/\\]}, '\\\\\0')}\"" }
          return "(#{value.join(' OR ')})"
        end
        value.gsub(%r{[" |=/\\]}, '\\\\\0')

      when /^date(?::(?<format>.*))?$/
        # TODO: grafana does not seem to allow multiselection of variables with date format - raise an error if this happens anyway
        Variable.format_as_date(value, Regexp.last_match(1))

      when ''
        # default
        if multi? && value.is_a?(Array)
          value = value.map { |item| "'#{item.gsub(/'/, "''")}'" }
          return value.join(',')
        end
        value.gsub(/'/, "''")

      else
        # glob and all unknown
        return "{#{value.join(',')}}" if multi? && value.is_a?(Array)

        value
      end
    end

    # @return [Boolean] true, if the value can contain multiple selections, i.e. can contain an Array or does contain all
    def multi?
      return true if @raw_value == '$__all'
      return @config['multi'] unless @config['multi'].nil?

      @raw_value.is_a? Array
    end

    # @return [Object] raw value of the variable
    def raw_value=(new_val)
      @raw_value = new_val
      @raw_value = @raw_value.to_s unless @raw_value.is_a?(Array)
      new_text = @raw_value
      if @config['options']
        val = @config['options'].select { |item| item['value'] == @raw_value }
        new_text = val.first['text'] unless val.empty?
      end
      @text = new_text
    end

    # Applies the date format according
    # {https://grafana.com/docs/grafana/latest/variables/variable-types/global-variables/#__from-and-__to}
    # and {https://momentjs.com/docs/#/displaying/} to a given value.
    # @param value [String] time as milliseconds to be formatted
    # @param format [String] format string in which the time value shall be returned
    # @return [String] time converted to the specified time format
    def self.format_as_date(value, format)
      return (Float(value) / 1000).to_i.to_s if format == 'seconds'
      return Time.at((Float(value) / 1000).to_i).utc.iso8601(3) if !format || (format == 'iso')

      # build array of known matches
      matches = []
      work_string = format
      until work_string.empty?
        tmp = work_string.scan(/^(?:M{1,4}|D{1,4}|d{1,4}|e|E|w{1,2}|W{1,2}|Y{4}|Y{2}|A|a|H{1,2}|
                                    h{1,2}|k{1,2}|m{1,2}|s{1,2}|S+|X)/x)

        if tmp.empty?
          matches << work_string[0]
          work_string = work_string.sub(/^#{work_string[0]}/, '')
        else
          matches << tmp[0]
          work_string = work_string.sub(/^#{tmp[0]}/, '')
        end
      end

      format_string = ''.dup
      matches.each do |match|
        replacement = DATE_MATCHES[match]
        format_string << (replacement || match)
      end

      Time.at((Float(value) / 1000).to_i).strftime(format_string)
    end

    private

    def init_values
      case @config['type']
      when 'constant'
        self.raw_value = @config['query']

      else
        if !@config['current'].nil?
          self.raw_value = @config['current']['value']
        else
          raise GrafanaError.new("Grafana variable with type '#{@config['type']}' and name '#{@config['name']}' could not be handled properly. Please raise a ticket.")
        end
      end
    end
  end
end
