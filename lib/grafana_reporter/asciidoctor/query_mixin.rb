# frozen_string_literal: true

module GrafanaReporter
  module Asciidoctor
    # This mixin contains several common methods, which can be used within the queries.
    module QueryMixin
      # Merges the given hashes to the current object by using the {Grafana::AbstractQuery#merge_variables} method.
      # It respects the priorities of the hashes and the object and allows only valid variables to be passed.
      # @param document_hash [Hash] variables from report template level
      # @param item_hash [Hash] variables from item configuration level, i.e. specific call, which may override document
      # @return [void]
      def merge_hash_variables(document_hash, item_hash)
        sel_doc_items = document_hash.select do |k, _v|
          k =~ /^var-/ || k == 'grafana-report-timestamp' || k =~ /grafana_default_(?:from|to)_timezone/
        end
        merge_variables(sel_doc_items.each_with_object({}) { |(k, v), h| h[k] = ::Grafana::Variable.new(v) })

        sel_items = item_hash.select do |k, _v|
          k =~ /^var-/ || k =~ /^render-/ || k =~ /filter_columns|format|replace_values_.*|transpose|column_divider|
                                                   row_divider|from_timezone|to_timezone/x
        end
        merge_variables(sel_items.each_with_object({}) { |(k, v), h| h[k] = ::Grafana::Variable.new(v) })

        self.timeout = item_hash['timeout'] || document_hash['grafana-default-timeout'] || timeout
        self.from = item_hash['from'] || document_hash['from'] || from
        self.to = item_hash['to'] || document_hash['to'] || to
      end

      # Formats the SQL results returned from grafana to an easier to use format.
      #
      # The result is being formatted as stated below:
      #
      #   {
      #     :header => [column_title_1, column_title_2],
      #     :content => [
      #                   [row_1_column_1, row_1_column_2],
      #                   [row_2_column_1, row_2_column_2]
      #                 ]
      #   }
      # @param raw_result [Hash] query result hash from grafana
      # @return [Hash] sql result formatted as stated above
      def preformat_sql_result(raw_result)
        results = {}
        results.default = []

        JSON.parse(raw_result)['results'].each_value do |query_result|
          if query_result.key?('error')
            results[:header] = results[:header] << ['SQL Error']
            results[:content] = [[query_result['error']]]

          elsif query_result['tables']
            query_result['tables'].each do |table|
              results[:header] = results[:header] << table['columns'].map { |header| header['text'] }
              results[:content] = table['rows']
            end

          end
        end

        results
      end

      # Transposes the given result.
      #
      # NOTE: Only the +:content+ of the given result hash is transposed. The +:header+ is ignored.
      #
      # @param result [Hash] preformatted sql hash, (see {#preformat_sql_result})
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
      # @param result [Hash] preformatted sql hash, (see {#preformat_sql_result})
      # @param filter_columns_variable [Grafana::Variable] column names, which shall be removed in the query result
      # @return [Hash] filtered query result
      def filter_columns(result, filter_columns_variable)
        return result unless filter_columns_variable

        filter_columns = filter_columns_variable.raw_value
        filter_columns.split(',').each do |filter_column|
          pos = result[:header][0].index(filter_column)

          unless pos.nil?
            result[:header][0].delete_at(pos)
            result[:content].each { |row| row.delete_at(pos) }
          end
        end

        result
      end

      # Uses the {Kernel#format} method to format values in the query results.
      #
      # The formatting will be applied separately for every column. Therefore the column formats have to be named
      # in the {Grafana::Variable#raw_value} and have to be separated by +,+ (comma). If no value is specified for
      # a column, no change will happen.
      # @param result [Hash] preformatted sql hash, (see {#preformat_sql_result})
      # @param formats [Grafana::Variable] formats, which shall be applied to the columns in the query result
      # @return [Hash] formatted query result
      # TODO: make sure that caught errors are also visible in logger
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
      # @param result [Hash] preformatted query result (see {#preformat_sql_result}.
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
        report_time ||= Variable.new(Time.now.to_s)
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

          delta_match = date_spec.match(%r{^(?<op>(?:-|\+))(?<count>\d+)?(?<unit>[smhdwMy])})
          if delta_match
            date = delta_date(date, ("#{delta_match[:op]}#{delta_match[:count] || 1}").to_i, delta_match[:unit])
            date_spec.slice!(%r{^#{delta_match[:op]}#{delta_match[:count]}#{delta_match[:unit]}})
          end

          raise TimeRangeUnknownError, orig_date unless fit_match || delta_match
        end

        # step back one second, if this is the 'to' time
        date = (date.to_time - 1).to_datetime if is_to_time

        (Time.at(date.to_time.to_i).to_i * 1000).to_s
      end

      private

      def delta_date(date, delta_count, time_letter)
        # substract specified time
        case time_letter
        when 's'
          date = (date.to_time + (delta_count * 1)).to_datetime
        when 'm'
          date = (date.to_time + (delta_count * 60)).to_datetime
        when 'h'
          date = (date.to_time + (delta_count * 60 * 60)).to_datetime
        when 'd'
          date = date.next_day(delta_count)
        when 'w'
          date = date.next_day(delta_count * 7)
        when 'M'
          date = date.next_month(delta_count)
        when 'y'
          date = date.next_year(delta_count)
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
end
