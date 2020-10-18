module Grafana
  # This class contains a representation of
  # {https://grafana.com/docs/grafana/latest/variables/templates-and-variables grafana variables},
  # aka grafana templates.
  #
  # The main need therefore rises in order to replace variables properly in different
  # texts, e.g. SQL statements or results.
  class Variable
    attr_reader :name, :text, :raw_value

    # @param config_or_value [Hash, Object] configuration hash of a variable out of an {Dashboard} instance or a value of any kind.
    def initialize(config_or_value)
      if config_or_value.is_a? Hash
        @config = config_or_value
        @name = @config['name']
        unless @config['current'].nil?
          @raw_value = @config['current']['value']
          @text = @config['current']['text']
        end
      else
        @config = {}
        @raw_value = config_or_value
        @text = config_or_value.to_s
      end
    end

    # Returns the stored value formatted according the given format.
    #
    # Supported formats are: +csv+, +distributed+, +doublequote+, +json+, +percentencode+, +pipe+, +raw+, +regex+, +singlequote+, +sqlstring+, +lucene+, +date+ or +glob+ (default)
    #
    # For details see {https://grafana.com/docs/grafana/latest/variables/advanced-variable-format-options Grafana Advanced variable format options}.
    #
    # For details of +date+ format, see {https://grafana.com/docs/grafana/latest/variables/variable-types/global-variables/#__from-and-__to}. Please note that input for +date+ format is unixtime in milliseconds.
    #
    # @param format [String] desired format
    # @return [String] value of stored variable according the specified format
    def value_formatted(format = '')
      value = @raw_value

      # handle value 'All' properly
      # TODO fix check for selection of All properly
      if value == 'All' or @text == 'All'
        if !@config['options'].empty?
          value = @config['options'].map { |item| item['value'] }
        elsif !@config['query'].empty?
          # TODO: replace variables in this query, too
          return @config['query']
          # TODO handle 'All' value properly for query attributes
        else
          # TODO how to handle All selection properly at this point?
        end
      end

      case format
      when 'csv'
        return value.join(',').to_s if multi?

        value.to_s

      when 'distributed'
        return value.join(",#{name}=") if multi?

        value
      when 'doublequote'
        if multi?
          value = value.map { |item| "\"#{item.gsub(/[\\]/, '\\\\').gsub(/"/, '\\"')}\"" }
          return value.join(',')
        end
        "\"#{value.gsub(/"/, '\\"')}\""

      when 'json'
        if multi?
          value = value.map { |item| "\"#{item.gsub(/["\\]/, '\\\\' + '\0')}\"" }
          return "[#{value.join(',')}]"
        end
        "\"#{value.gsub(/"/, '\\"')}\""

      when 'percentencode'
        value = "{#{value.join(',')}}" if multi?
        ERB::Util.url_encode(value)

      when 'pipe'
        return value.join('|') if multi?

        value

      when 'raw'
        return "{#{value.join(',')}}" if multi?

        value

      when 'regex'
        if multi?
          value = value.map { |item| item.gsub(%r{[/$\.\|\\]}, '\\\\' + '\0') }
          return "(#{value.join('|')})"
        end
        value.gsub(%r{[/$\.\|\\]}, '\\\\' + '\0')

      when 'singlequote'
        if multi?
          value = value.map { |item| "'#{item.gsub(/[']/, '\\\\' + '\0')}'" }
          return value.join(',')
        end
        "'#{value.gsub(/[']/, '\\\\' + '\0')}'"

      when 'sqlstring'
        if multi?
          value = value.map { |item| "'#{item.gsub(/'/, "''")}'" }
          return value.join(',')
        end
        "'#{value.gsub(/'/, "''")}'"

      when 'lucene'
        if multi?
          value = value.map { |item| "\"#{item.gsub(%r{[" |=/\\]}, '\\\\' + '\0')}\"" }
          return "(#{value.join(' OR ')})"
        end
        value.gsub(%r{[" |=/\\]}, '\\\\' + '\0')

      when /^date(?:[:](?<format>.*))?$/
        #TODO validate how grafana handles multivariables with date format
        get_date_formatted(value, $1)

      when ''
        # default
        if multi?
          value = value.map { |item| "'#{item.gsub(/'/, "''")}'" }
          return value.join(',')
        end
        value.gsub(/'/, "''")

      else
        # glob and all unknown
	#TODO add check for array value properly for all cases
        return "{#{value.join(',')}}" if multi? and value.is_a?(Array)

        value
      end
    end

    # @return [Boolean] true, if the value can contain multiple selections, i.e. is an Array
    def multi?
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

    private

    # Realize time formatting according
    # {https://grafana.com/docs/grafana/latest/variables/variable-types/global-variables/#__from-and-__to}
    # and {https://momentjs.com/docs/#/displaying/}.
    def get_date_formatted(value, format)
      return (Float(value) / 1000).to_i.to_s if format == 'seconds'
      return Time.at((Float(value) / 1000).to_i).utc.iso8601(3) if !format or format == 'iso'

      # build array of known matches
      matches = []
      work_string = format
      while work_string.length > 0
        tmp = work_string.scan(/^(?:M{1,4}|D{1,4}|d{1,4}|e|E|w{1,2}|W{1,2}|Y{4}|Y{2}|A|a|H{1,2}|h{1,2}|k{1,2}|m{1,2}|s{1,2}|S+|X)/)
        unless tmp.empty?
          matches << tmp[0]
          work_string.delete_prefix!(tmp[0])
        else
          matches << work_string[0]
          work_string.delete_prefix!(work_string[0])
        end
      end

      #TODO move case when to hash
      format_string = ""
      matches.each do |match|
        format_string += case match
          when 'M'
            '%-m'
          when 'MM'
            '%m'
          when 'MMM'
            '%b'
          when 'MMMM'
            '%B'
          when 'D'
            '%-d'
          when 'DD'
            '%d'
          when 'DDD'
            '%-j'
          when 'DDDD'
            '%j'
          when 'YY'
            '%y'
          when 'YYYY'
            '%Y'
          when 'd'
            '%w'
          when 'ddd'
            '%a'
          when 'dddd'
            '%A'
          when 'e'
            '%w'
          when 'E'
            '%u'
          when 'w'
            '%-U'
          when 'ww'
            '%U'
          when 'W'
            '%-V'
          when 'WW'
            '%V'
          when 'YY'
            '%y'
          when 'YYYY'
            '%Y'
          when 'A'
            '%p'
          when 'a'
            '%P'
          when 'H'
            '%-H'
          when 'HH'
            '%H'
          when 'h'
            '%-I'
          when 'hh'
            '%I'
          when 'm'
            '%-M'
          when 'mm'
            '%M'
          when 's'
            '%-S'
          when 'ss'
            '%S'
          when 'X'
            '%s'
          else
            match
          end
      end

      Time.at((Float(value) / 1000).to_i).strftime(format_string)
    end
  end
end
