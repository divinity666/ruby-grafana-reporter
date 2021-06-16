# frozen_string_literal: true

module GrafanaReporter
  # @abstract Override {#pre_process} and {#post_process} in subclass.
  #
  # Superclass containing everything for all queries towards grafana.
  class AbstractQuery
    attr_accessor :datasource
    attr_writer :raw_query
    attr_reader :variables, :result, :panel, :dashboard

    def timeout
      # TODO: check where value priorities should be evaluated
      return @variables['timeout'].raw_value if @variables['timeout']
      return @variables['grafana_default_timeout'].raw_value if @variables['grafana_default_timeout']

      nil
    end

    # @param grafana_obj [Object] {Grafana::Grafana}, {Grafana::Dashboard} or {Grafana::Panel} object for which the query is executed
    # @param opts [Hash] hash options, which may consist of:
    # @option opts [Hash] :variables hash of variables, which shall be used to replace variable references in the query
    # @option opts [Boolean] :ignore_dashboard_defaults True if {#assign_dashboard_defaults} should not be called
    # @option opts [Boolean] :do_not_use_translated_times True if given from and to times should used as is, without being resolved to reporter times - using this parameter can lead to inconsistent report contents
    def initialize(grafana_obj, opts = {})
      if grafana_obj.is_a?(Grafana::Panel)
        @panel = grafana_obj
        @dashboard = @panel.dashboard
        @grafana = @dashboard.grafana

      elsif grafana_obj.is_a?(Grafana::Dashboard)
        @dashboard = grafana_obj
        @grafana = @dashboard.grafana

      elsif grafana_obj.is_a?(Grafana::Grafana)
        @grafana = grafana_obj

      elsif !grafana_obj
        # nil given

      else
        raise GrafanaReporterError, "Internal error in AbstractQuery: given object is of type #{grafana_obj.class.name}, which is not supported"
      end
      @variables = {}
      @variables['from'] = Grafana::Variable.new(nil)
      @variables['to'] = Grafana::Variable.new(nil)

      assign_dashboard_defaults unless opts[:ignore_dashboard_defaults]
      opts[:variables].each { |k, v| assign_variable(k, v) } if opts[:variables].is_a?(Hash)

      @translate_times = true
      @translate_times = false if opts[:do_not_use_translated_times]
    end

    # @abstract
    #
    # Runs the whole process to receive values properly from this query:
    # - calls {#pre_process}
    # - executes this query against the {Grafana::AbstractDatasource} implementation instance
    # - calls {#post_process}
    #
    # @return [Hash] result of the query in standardized format
    def execute
      return @result unless @result.nil?

      from = @variables['from'].raw_value
      to = @variables['to'].raw_value
      if @translate_times
        from = translate_date(@variables['from'], @variables['grafana_report_timestamp'], false, @variables['from_timezone'] ||
                              @variables['grafana_default_from_timezone'])
        to = translate_date(@variables['to'], @variables['grafana_report_timestamp'], true, @variables['to_timezone'] ||
                            @variables['grafana_default_to_timezone'])
      end

      pre_process
      raise DatasourceNotSupportedError.new(@datasource, self) if @datasource.is_a?(Grafana::UnsupportedDatasource)

      begin
        @result = @datasource.request(from: from, to: to, raw_query: raw_query, variables: grafana_variables,
                                      prepared_request: @grafana.prepare_request, timeout: timeout)
      rescue ::Grafana::GrafanaError
        # grafana errors will be directly passed through
        raise
      rescue GrafanaReporterError
        # grafana errors will be directly passed through
        raise
      rescue StandardError => e
        raise DatasourceRequestInternalError.new(@datasource, e.message)
      end

      raise DatasourceRequestInvalidReturnValueError.new(@datasource, @result) unless datasource_response_valid?
      post_process
      @result
    end

    # Overwrite this function to extract a proper raw query value from this object.
    #
    # If the property +@raw_query+ is not set manually by the calling object, this
    # method may be overwritten to extract the raw query from this object instead.
    def raw_query
      @raw_query
    end

    # @abstract
    #
    # Overwrite this function to perform all necessary actions, before the query is actually executed.
    # Here you can e.g. set values of variables or similar.
    #
    # Especially for direct queries, it is essential to set the +@datasource+ variable at latest here in the
    # subclass.
    def pre_process
      raise NotImplementedError
    end

    # @abstract
    #
    # Use this function to format the raw result of the @result variable to conform to the expected return value.
    def post_process
      raise NotImplementedError
    end

    # Transposes the given result.
    #
    # NOTE: Only the +:content+ of the given result hash is transposed. The +:header+ is ignored.
    #
    # @param result [Hash] preformatted sql hash, (see {Grafana::AbstractDatasource#request})
    # @param transpose_variable [Grafana::Variable] true, if the result hash shall be transposed
    # @return [Hash] transposed query result
    def transpose(result, transpose_variable)
      return result unless transpose_variable
      return result unless transpose_variable.raw_value == 'true'

      result[:content] = result[:content].transpose

      result
    end

    # Filters columns out of the query result.
    #
    # Multiple columns may be filtered. Therefore the column titles have to be named in the
    # {Grafana::Variable#raw_value} and have to be separated by +,+ (comma).
    # @param result [Hash] preformatted sql hash, (see {Grafana::AbstractDatasource#request})
    # @param filter_columns_variable [Grafana::Variable] column names, which shall be removed in the query result
    # @return [Hash] filtered query result
    def filter_columns(result, filter_columns_variable)
      return result unless filter_columns_variable

      filter_columns = filter_columns_variable.raw_value
      filter_columns.split(',').each do |filter_column|
        pos = result[:header].index(filter_column)

        unless pos.nil?
          result[:header].delete_at(pos)
          result[:content].each { |row| row.delete_at(pos) }
        end
      end

      result
    end

    # Uses the Kernel#format method to format values in the query results.
    #
    # The formatting will be applied separately for every column. Therefore the column formats have to be named
    # in the {Grafana::Variable#raw_value} and have to be separated by +,+ (comma). If no value is specified for
    # a column, no change will happen.
    # @param result [Hash] preformatted sql hash, (see {Grafana::AbstractDatasource#request})
    # @param formats [Grafana::Variable] formats, which shall be applied to the columns in the query result
    # @return [Hash] formatted query result
    def format_columns(result, formats)
      return result unless formats

      formats.text.split(',').each_index do |i|
        format = formats.text.split(',')[i]
        next if format.empty?

        result[:content].map do |row|
          next unless row.length > i

          begin
            row[i] = format % row[i] if row[i]
          rescue StandardError => e
            @grafana.logger.error(e.message)
            row[i] = e.message
          end
        end
      end
      result
    end

    # Used to replace values in a query result according given configurations.
    #
    # The given variables will be applied to an appropriate column, depending
    # on the naming of the variable. The variable name ending specifies the column,
    # e.g. a variable named +replace_values_2+ will be applied to the second column.
    #
    # The {Grafana::Variable#text} needs to contain the replace specification.
    # Multiple replacements can be specified by separating them with +,+. If a
    # literal comma is needed, it can be escaped with a backslash:  +\\,+.
    #
    # The rule will be separated from the replacement text with a colon +:+.
    # If a literal colon is wanted, it can be escaped with a backslash: +\\:+.
    #
    # Examples:
    # - Basic string replacement
    #    MyTest:ThisValue
    # will replace all occurences of the text 'MyTest' with 'ThisValue'.
    # - Number comparison
    #     <=10:OK
    # will replace all values smaller or equal to 10 with 'OK'.
    # - Regular expression
    #     ^[^ ]\\+ (\d+)$:\1 is the answer
    # will replace all values matching the pattern, e.g. 'answerToAllQuestions 42' to
    # '42 is the answer'. Important to know: the regular expressions always have to start
    # with +^+ and end with +$+, i.e. the expression itself always has to match
    # the whole content in one field.
    # @param result [Hash] preformatted query result (see {Grafana::AbstractDatasource#request}.
    # @param configs [Array<Grafana::Variable>] one variable for replacing values in one column
    # @return [Hash] query result with replaced values
    # TODO: make sure that caught errors are also visible in logger
    def replace_values(result, configs)
      return result if configs.empty?

      configs.each do |key, formats|
        cols = key.split('_')[2..-1].map(&:to_i)

        formats.text.split(/(?<!\\),/).each_index do |j|
          format = formats.text.split(/(?<!\\),/)[j]

          arr = format.split(/(?<!\\):/)
          raise MalformedReplaceValuesStatementError, format if arr.length != 2

          k = arr[0]
          v = arr[1]
          k.gsub!(/\\([:,])/, '\1')
          v.gsub!(/\\([:,])/, '\1')
          result[:content].map do |row|
            (row.length - 1).downto 0 do |i|
              if cols.include?(i + 1) || cols.empty?

                # handle regular expressions
                if k.start_with?('^') && k.end_with?('$')
                  begin
                    row[i] = row[i].to_s.gsub(/#{k}/, v) if row[i].to_s =~ /#{k}/
                  rescue StandardError => e
                    @grafana.logger.error(e.message)
                    row[i] = e.message
                  end

                # handle value comparisons
                elsif (match = k.match(/^ *(?<operator>[<>]=?|<>|=) *(?<number>[+-]?\d+(?:\.\d+)?)$/))
                  skip = false
                  begin
                    val = Float(row[i])
                  rescue StandardError
                    # value cannot be converted to number, simply ignore it as the comparison does not fit here
                    skip = true
                  end

                  unless skip
                    begin
                      op = match[:operator].gsub(/^=$/, '==').gsub(/^<>$/, '!=')
                      if val.public_send(op.to_sym, Float(match[:number]))
                        row[i] = if v.include?('\\1')
                                   v.gsub(/\\1/, row[i].to_s)
                                 else
                                   v
                                 end
                      end
                    rescue StandardError => e
                      row[i] = e.message
                    end
                  end

                # handle as normal comparison
                elsif row[i].to_s == k
                  row[i] = v
                end
              end
            end
          end
        end
      end

      result
    end

    # Used to build a output format matching the requested report format.
    # @param result [Hash] preformatted sql hash, (see {Grafana::AbstractDatasource#request})
    # @param opts [Hash] options for the formatting:
    # @option opts [Grafana::Variable] :row_divider requested row divider for the result table
    # @option opts [Grafana::Variable] :column_divider requested row divider for the result table
    # @option opts [Regex or String] :escape_regex regular expression which specifies a part of a cell content, which has to be escaped
    # @option opts [String] :escape_replacement specifies how the found :escape_regex shall be replaced
    # @return [String] formatted table result in requested output format
    def format_table_output(result, opts)
      opts = { escape_regex: '|', escape_replacement: '\\|', row_divider: Grafana::Variable.new('| '), column_divider: Grafana::Variable.new(' | ') }.merge(opts.delete_if {|_k, v| v.nil? })

      result[:content].map do |row|
        opts[:row_divider].raw_value + row.map do |item|
          item.to_s.gsub(opts[:escape_regex], opts[:escape_replacement])
        end.join(opts[:column_divider].raw_value)
      end
    end

    # Used to translate the relative date strings used by grafana, e.g. +now-5d/w+ to the
    # correct timestamp. Reason is that grafana does this in the frontend, which we have
    # to emulate here for the reporter.
    #
    # Additionally providing this function the +report_time+ assures that all queries
    # rendered within one report will use _exactly_ the same timestamp in those relative
    # times, i.e. there shouldn't appear any time differences, no matter how long the
    # report is running.
    # @param orig_date [String] time string provided by grafana, usually +from+ or +to+.
    # @param report_time [Grafana::Variable] report start time
    # @param is_to_time [Boolean] true, if the time should be calculated for +to+, false if it shall be
    #   calculated for +from+
    # @param timezone [Grafana::Variable] timezone to use, if not system timezone
    # @return [String] translated date as timestamp string
    def translate_date(orig_date, report_time, is_to_time, timezone = nil)
      # TODO: add test case for creation of variable, if not given, maybe also print a warning
      report_time ||= ::Grafana::Variable.new(Time.now.to_s)
      orig_date = orig_date.raw_value if orig_date.is_a?(Grafana::Variable)
      return (DateTime.parse(report_time.raw_value).to_time.to_i * 1000).to_s unless orig_date
      return orig_date if orig_date =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
      return orig_date if orig_date =~ /^\d+$/

      # check if a relative date is mentioned
      date_spec = orig_date.clone

      date_spec.slice!(/^now/)
      raise TimeRangeUnknownError, orig_date unless date_spec

      date = DateTime.parse(report_time.raw_value)
      # TODO: allow from_translated or similar in ADOC template
      date = date.new_offset(timezone.raw_value) if timezone

      until date_spec.empty?
        fit_match = date_spec.match(%r{^/(?<fit>[smhdwMy])})
        if fit_match
          date = fit_date(date, fit_match[:fit], is_to_time)
          date_spec.slice!(%r{^/#{fit_match[:fit]}})
        end

        delta_match = date_spec.match(/^(?<op>(?:-|\+))(?<count>\d+)?(?<unit>[smhdwMy])/)
        if delta_match
          date = delta_date(date, "#{delta_match[:op]}#{delta_match[:count] || 1}".to_i, delta_match[:unit])
          date_spec.slice!(/^#{delta_match[:op]}#{delta_match[:count]}#{delta_match[:unit]}/)
        end

        raise TimeRangeUnknownError, orig_date unless fit_match || delta_match
      end

      # step back one second, if this is the 'to' time
      date = (date.to_time - 1).to_datetime if is_to_time

      (Time.at(date.to_time.to_i).to_i * 1000).to_s
    end

    private

    # Used to specify variables to be used for this query. This method ensures, that only the values of the
    # {Grafana::Variable} stored in the +variables+ Array are overwritten.
    # @param name [String] name of the variable to set
    # @param variable [Grafana::Variable] variable from which the {Grafana::Variable#raw_value} will be assigned to the query variables
    def assign_variable(name, variable)
      variable = Grafana::Variable.new(variable) unless variable.is_a?(Grafana::Variable)

      @variables[name] ||= variable
      @variables[name].raw_value = variable.raw_value
    end

    # Sets default configurations from the given {Grafana::Dashboard} and store them as settings in the
    # {AbstractQuery}.
    #
    # Following data is extracted:
    # - +from+, by {Grafana::Dashboard#from_time}
    # - +to+, by {Grafana::Dashboard#to_time}
    # - and all variables as {Grafana::Variable}, prefixed with +var-+, as grafana also does it
    def assign_dashboard_defaults
      return unless @dashboard

      assign_variable('from', @dashboard.from_time)
      assign_variable('to', @dashboard.to_time)
      @dashboard.variables.each { |item| assign_variable("var-#{item.name}", item) }
    end

    def datasource_response_valid?
      return false if @result.nil?
      return false unless @result.is_a?(Hash)
      # TODO: check if it should be ok if a datasource request returns an empty hash only
      return true if @result.empty?
      return false unless @result.has_key?(:header)
      return false unless @result.has_key?(:content)
      return false unless @result[:header].is_a?(Array)
      return false unless @result[:content].is_a?(Array)

      true
    end

    # @return [Hash<String, Variable>] all grafana variables stored in this query, i.e. the variable name
    #  is prefixed with +var-+
    def grafana_variables
      @variables.select { |k, _v| k =~ /^var-.+/ }
    end

    def delta_date(date, delta_count, time_letter)
      # substract specified time
      case time_letter
      when 's'
        (date.to_time + (delta_count * 1)).to_datetime
      when 'm'
        (date.to_time + (delta_count * 60)).to_datetime
      when 'h'
        (date.to_time + (delta_count * 60 * 60)).to_datetime
      when 'd'
        date.next_day(delta_count)
      when 'w'
        date.next_day(delta_count * 7)
      when 'M'
        date.next_month(delta_count)
      when 'y'
        date.next_year(delta_count)
      end
    end

    def fit_date(date, fit_letter, is_to_time)
      # fit to specified time frame
      case fit_letter
      when 's'
        date = DateTime.new(date.year, date.month, date.day, date.hour, date.min, date.sec, date.zone)
        date = (date.to_time + 1).to_datetime if is_to_time
      when 'm'
        date = DateTime.new(date.year, date.month, date.day, date.hour, date.min, 0, date.zone)
        date = (date.to_time + 60).to_datetime if is_to_time
      when 'h'
        date = DateTime.new(date.year, date.month, date.day, date.hour, 0, 0, date.zone)
        date = (date.to_time + 60 * 60).to_datetime if is_to_time
      when 'd'
        date = DateTime.new(date.year, date.month, date.day, 0, 0, 0, date.zone)
        date = date.next_day(1) if is_to_time
      when 'w'
        date = DateTime.new(date.year, date.month, date.day, 0, 0, 0, date.zone)
        date = if date.wday.zero?
                 date.prev_day(7)
               else
                 date.prev_day(date.wday - 1)
               end
        date = date.next_day(7) if is_to_time
      when 'M'
        date = DateTime.new(date.year, date.month, 1, 0, 0, 0, date.zone)
        date = date.next_month if is_to_time
      when 'y'
        date = DateTime.new(date.year, 1, 1, 0, 0, 0, date.zone)
        date = date.next_year if is_to_time
      end

      date
    end
  end
end
