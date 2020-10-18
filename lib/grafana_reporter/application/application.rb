module GrafanaReporter
  # This module contains all classes, which are used by the grafana reporter
  # application. The application is a set of classes, which allows to run the
  # reporter in several ways.
  #
  # If you intend to use the reporter functionality, without the application,
  # it might be helpful to not use the classes from here.
  module Application
    # This class contains the main application to run the grafana reporter.
    #
    # It can be run to test the grafana connection, render a single template
    # or run as a service.
    class Application
      def initialize
        @logger = ::Logger.new(STDERR, level: :unknown)
        @reports = []
      end

      # Can be used to set a {Configuration} object to the application.
      #
      # This is mainly helpful in testing the application or in an
      # integrated use.
      # @param config {Configuration} configuration to be used by the application
      # @return [void]
      def config=(config)
        @logger = config.logger || @logger
        @config = config
      end

      # This is the main method, which is called, if the application is
      # run in standalone mode.
      # @param params [Array] normally the ARGV command line parameters
      # @return [Integer] see {#run}
      def configure_and_run(params = [])
        config = GrafanaReporter::Configuration.new
        config.logger.level = ::Logger::Severity::INFO
        result = config.configure_by_command_line(params)
        return result if result != 0

        self.config = config
        run
      end

      # Runs the application with the current set {Configuration} object.
      # @return [Integer] value smaller than 0, if error. 0 if successfull
      def run
        begin
          @config.validate
        rescue ConfigurationError => e
          puts e.message
          return -2
        end

        case @config.mode
        when Configuration::MODE_CONNECTION_TEST
          res = Grafana::Grafana.new(@config.grafana_host(@config.test_instance), @config.grafana_api_key(@config.test_instance), logger: @logger).test_connection
          puts res

        when Configuration::MODE_SINGLE_RENDER
          @config.report_class.new(@config, @config.template, @config.to_file).create_report

        when Configuration::MODE_SERVICE
          run_webserver
        end
        0
      end

      private

      def clean_outdated_temporary_reports
        clean_time = Time.now - 60 * 60 * @config.report_retention
        @reports.select { |report| report.done && clean_time > report.end_time }.each do |report|
          @reports.delete(report).delete_file
        end
      end

      def run_webserver
        # start webserver
        server = TCPServer.new(@config.webserver_port)
        @logger.info("Server listening on port #{@config.webserver_port}...")

        @progress_reporter = Thread.new {}

        loop do
          # step 1) accept incoming connection
          socket = server.accept

          # step 2) print the request headers (separated by a blank line e.g. \r\n)
          request = ''
          line = ''
          begin
            until line == "\r\n"
              line = socket.readline
              request += line
            end
          rescue EOFError => e
            @logger.debug("Webserver EOFError: #{e.message}")
          end

          begin
            response = handle_request(request)
            socket.write response
          rescue WebserviceUnknownPathError => e
            @logger.debug(e.message)
            socket.write http_response(404, '', e.message)
          rescue MissingTemplateError => e
            @logger.error(e.message)
            socket.write http_response(400, 'Bad Request', e.message)
          rescue WebserviceGeneralRenderingError => e
            @logger.fatal(e.message)
            socket.write http_response(400, 'Bad Request', e.message)
          rescue StandardError => e
            @logger.fatal(e.message)
            socket.write http_response(400, 'Bad Request', e.message)
          ensure
            socket.close
          end

          unless @progress_reporter.alive?
            @progress_reporter = Thread.new do
              running_reports = @reports.reject(&:done)
              until running_reports.empty?
                @logger.info("#{running_reports.length} report(s) in progress: #{running_reports.map { |report| (report.progress * 100).to_i.to_s + '% (running ' + report.execution_time.to_i.to_s + ' secs)' }.join(', ')}") unless running_reports.empty?
                sleep 5
                running_reports = @reports.reject(&:done)
              end
              # puts "no more running reports - stopping to report progress"
            end
          end

          clean_outdated_temporary_reports
        end
      end

      def handle_request(request)
        raise WebserviceUnknownPathError, request.split("\r\n")[0] if request.nil?
        raise WebserviceUnknownPathError, request.split("\r\n")[0] if request.split("\r\n")[0].nil?

        query_string = request.split("\r\n")[0].gsub(%r{(?:[^\?]+[\?])(.*)(?: HTTP/.*)$}, '\1')
        query_parameters = CGI.parse(query_string)

        @logger.debug("Received request: #{request.split("\r\n")[0]}")
        @logger.debug('query_parameters: ' + query_parameters.to_s)

        # read URL parameters
        attrs = {}
        query_parameters.each do |k, v|
          attrs[k] = v.length == 1 ? v[0] : v
        end

        if request.split("\r\n")[0] =~ %r{^GET /render[\? ]}
          # build report
          template_file = @config.templates_folder.to_s + attrs['var-template'].to_s + '.adoc'

          file = Tempfile.new('gf_pdf_', @config.reports_folder)
          begin
            FileUtils.chmod('+r', file.path)
          rescue StandardError => e
            @logger.debug("File permissions could not be set for #{file.path}: #{e.message}")
          end

          report = @config.report_class.new(@config, template_file, file, attrs)
          Thread.new do
            report.create_report
          end
          @reports << report

          return http_response(302, 'Found', nil, Location: "/view_report?report_id=#{report.object_id}")

        elsif request.split("\r\n")[0] =~ %r{^GET /overview[\? ]}
          # show overview for current reports
          return get_reports_status_as_html(@reports)

        elsif request.split("\r\n")[0] =~ %r{^GET /view_report[\? ]}
          # view report if already available, or show status view
          report = @reports.select { |r| r.object_id.to_s == attrs['report_id'].to_s }.first
          raise WebserviceGeneralRenderingError, 'view_report has been called without valid id' if report.nil?

          # show report status
          return get_reports_status_as_html([report]) if !report.done || !report.error.empty?

          # provide report
          @logger.debug("Returning PDF report at #{report.path}")
          content = File.read(report.path)
          return http_response(200, 'OK', content, "Content-Type": 'application/pdf') if content.start_with?("%PDF")
          # TODO properly provide file as zip
          return http_response(200, 'OK', content, "Content-Type": 'application/octet-stream', "Content-Disposition": "attachment; filename=report.zip")

        elsif request.split("\r\n")[0] =~ %r{^GET /cancel_report[\? ]}
          # view report if already available, or show status view
          report = @reports.select { |r| r.object_id.to_s == attrs['report_id'].to_s }.first
          raise WebserviceGeneralRenderingError, 'cancel_report has been called without valid id' if report.nil?

          report.cancel! unless report.done

          # redirect to view_report page
          return http_response(302, 'Found', nil, Location: "/view_report?report_id=#{report.object_id}")

        elsif request.split("\r\n")[0] =~ %r{^GET /view_log[\? ]}
          # view report if already available, or show status view
          report = @reports.select { |r| r.object_id.to_s == attrs['report_id'].to_s }.first
          raise WebserviceGeneralRenderingError, 'view_log has been called without valid id' if report.nil?

          content = report.full_log

          return  http_response(200, 'OK', content, "Content-Type": 'text/plain')
        end

        raise WebserviceUnknownPathError, request.split("\r\n")[0]
      end

      def get_reports_status_as_html(reports)
        i = reports.length

        content = '<html><head></head><body><table><thead><th>#</th><th>Start Time</th><th>End Time</th><th>Template</th><th>Execution time</th><th>Status</th><th>Error</th><th>Action</th></thead>' +
                  reports.reverse.map do |report|
                    "<tr><td>#{(i -= 1)}</td><td>#{report.start_time}</td><td>#{report.end_time}</td><td>#{report.template}</td><td>#{report.execution_time.to_i} secs</td><td>#{report.status} (#{(report.progress * 100).to_i}%)</td><td>#{report.error.join('<br>')}</td><td>#{!report.done && !report.cancel ? "<a href=\"/cancel_report?report_id=#{report.object_id}\">Cancel</a>&nbsp;" : ''}#{(report.status == 'finished') || (report.status == 'cancelled') ? "<a href=\"/view_report?report_id=#{report.object_id}\">View</a>&nbsp;" : '&nbsp;'}<a href=\"/view_log?report_id=#{report.object_id}\">Log</a></td></tr>"
                  end.join('') +
                  '</table></body></html>'

        http_response(200, 'OK', content, "Content-Type": 'text/html')
      end

      def http_response(code, text, body, opts = {})
        "HTTP/1.1 #{code} #{text}\r\n#{opts.map { |k, v| "#{k}: #{v}" }.join("\r\n")}#{body ? "\r\nContent-Length: #{body.to_s.bytesize}" : ''}\r\n\r\n#{body}"
      end
    end
  end
end
