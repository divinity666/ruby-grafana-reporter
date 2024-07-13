# frozen_string_literal: true

module GrafanaReporter
  module Application
    # This class provides the webservice for the reporter application. It does not
    # make use of `webrick` or similar, so that it can be used without futher dependencies
    # in conjunction with the standard asciidoctor docker container.
    class Webservice
      # Array of possible webservice running states
      STATUS = %I[stopped running stopping].freeze

      def initialize
        @reports = []
        @status = :stopped
      end

      # Runs the webservice with the given {Configuration} object.
      def run(config)
        @config = config
        @logger = config.logger

        # start webserver
        @server = TCPServer.new(@config.webserver_port)
        @logger.info("Server listening on port #{@config.webserver_port}...")

        @progress_reporter = Thread.new {}

        @status = :running
        begin
          accept_requests_loop
        rescue SystemExit, Interrupt
          @logger.info("Server shutting down.")
          stop!
          retry
        end
        @status = :stopped
      end

      # @return True, if webservice is stopped, false otherwise
      def stopped?
        @status == :stopped
      end

      # @return True, if webservice is up and running, false otherwise
      def running?
        @status == :running
      end

      # Forces stopping the webservice.
      def stop!
        @status = :stopping

        # invoke a new request, so that the webservice stops.
        socket = TCPSocket.new('localhost', @config.webserver_port)
        socket.send '', 0
        socket.close
      end

      private

      def accept_requests_loop
        loop do
          # step 1) accept incoming connection
          socket = @server.accept

          # stop webservice properly, if shall be shutdown
          if @status == :stopping
            socket.close
            break
          end

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
          rescue WebserviceGeneralRenderingError => e
            @logger.error(e.message)
            socket.write http_response(400, 'Bad Request', e.message)
          rescue StandardError => e
            @logger.fatal("#{e.message}\n#{e.backtrace.join("\n")}")
            socket.write http_response(400, 'Bad Request', "#{e.message}\n#{e.backtrace.join("\n")}")
          ensure
            socket.close
          end

          log_report_progress
          clean_outdated_temporary_reports
        end
      end

      def log_report_progress
        return if @progress_reporter.alive?

        @progress_reporter = Thread.new do
          running_reports = @reports.reject(&:done)
          until running_reports.empty?
            unless running_reports.empty?
              @logger.info("#{running_reports.length} report(s) in progress: "\
                           "#{running_reports.map do |report|
                                "#{(report.progress * 100).to_i}% (running #{report.execution_time.to_i} secs)"
                              end.join(', ')}")
            end
            sleep 5
            running_reports = @reports.reject(&:done)
          end
          # puts "no more running reports - stopping to report progress"
        end
      end

      def clean_outdated_temporary_reports
        clean_time = Time.now - 60 * 60 * @config.report_retention
        @reports.select { |report| report.done && clean_time > report.end_time }.each do |report|
          @reports.delete(report).delete_file
        end
      end

      def handle_request(request)
        raise WebserviceUnknownPathError, request.split("\r\n")[0] if request.nil?
        raise WebserviceUnknownPathError, request.split("\r\n")[0] if request.split("\r\n")[0].nil?

        query_string = request.split("\r\n")[0].gsub(%r{(?:[^?]+\?)(.*)(?: HTTP/.*)$}, '\1')
        query_parameters = CGI.parse(query_string)

        @logger.debug("Received request: #{request.split("\r\n")[0]}")
        @logger.debug("query_parameters: #{query_parameters}")

        # read URL parameters
        attrs = {}
        query_parameters.each do |k, v|
          attrs[k] = v.length == 1 ? v[0] : v
        end

        parsed_url = request.split("\r\n")[0].match(%r{(?<verb>GET|POST|DELETE) (?<subpath>/.*?)(?:api/v1/(?<api_action>render|status|cancel))?(?<html_action>render|overview|view_report|cancel_report|view_log)?[ ?]})
        parsed_url = {} if not parsed_url

        case parsed_url
        # API calls
        when -> (h) { h['verb'] == 'POST' && h['api_action'] == 'render' }
          return render_report(attrs, parsed_url['subpath'], true)

        when -> (h) { h['verb'] == 'GET' && h['api_action'] == 'status' }
          return report_status(attrs)

        when -> (h) { h['verb'] == 'DELETE' && h['api_action'] == 'cancel' }
          return cancel_report(attrs, parsed_url['subpath'], true)

        # HTML calls
        when -> (h) { h['verb'] == 'GET' && h['html_action'] == 'render' }
          return render_report(attrs, parsed_url['subpath'])

        when -> (h) { h['verb'] == 'GET' && h['html_action'] == 'overview' }
          # show overview for current reports
          return get_reports_status_as_html(@reports, parsed_url['subpath'])

        when -> (h) { h['verb'] == 'GET' && h['html_action'] == 'view_report' }
          return view_report(attrs, parsed_url['subpath'])

        when -> (h) { h['verb'] == 'GET' && h['html_action'] == 'cancel_report' }
          return cancel_report(attrs, parsed_url['subpath'])

        when -> (h) { h['verb'] == 'GET' && h['html_action'] == 'view_log' }
          return view_log(attrs)
        end

        raise WebserviceUnknownPathError, request.split("\r\n")[0]
      end

      def report_status(attrs)
        report = @reports.select { |r| r.object_id.to_s == attrs['report_id'].to_s }.first
        raise WebserviceGeneralRenderingError, 'report_status has been called without valid id' if report.nil?

        response = {
          report_id: report.object_id,
          progress: report.progress,
          state: report.status,
          done: report.done,
          execution_time: report.execution_time
        }

        http_response(200, 'OK', JSON.generate(response), "Content-Type": "application/json")
      end

      def view_log(attrs)
        # view report if already available, or show status view
        report = @reports.select { |r| r.object_id.to_s == attrs['report_id'].to_s }.first
        raise WebserviceGeneralRenderingError, 'view_log has been called without valid id' if report.nil?

        content = report.full_log

        http_response(200, 'OK', content, "Content-Type": 'text/plain')
      end

      def cancel_report(attrs, subpath, as_json=false)
        # view report if already available, or show status view
        report = @reports.select { |r| r.object_id.to_s == attrs['report_id'].to_s }.first
        raise WebserviceGeneralRenderingError, 'cancel_report has been called without valid id' if report.nil?

        report.cancel! unless report.done

        # redirect to view_report page
        return http_response(302, 'Found', nil, Location: "#{subpath}view_report?report_id=#{report.object_id}") if not as_json

        http_response(200, 'OK', nil)
      end

      def view_report(attrs, subpath)
        # view report if already available, or show status view
        report = @reports.select { |r| r.object_id.to_s == attrs['report_id'].to_s }.first
        raise WebserviceGeneralRenderingError, 'view_report has been called without valid id' if report.nil?

        # show report status
        return get_reports_status_as_html([report], subpath) if !report.done || !report.error.empty?

        # provide report
        @logger.debug("Returning report file #{report.path}")
        content = File.read(report.path, mode: 'rb')
        return http_response(200, 'OK', content, "Content-Type": 'application/pdf') if content.start_with?('%PDF')

        return http_response(200, 'OK', content, "Content-Type": 'application/octet-stream',
                                                 "Content-Disposition": 'attachment; '\
                                                 "filename=report_#{attrs['report_id']}.zip") if content.start_with?('PK')

        http_response(200, 'OK', content, "Content-Type": 'application/octet-stream',
                                          "Content-Disposition": 'attachment; '\
                                          "filename=report_#{attrs['report_id']}.#{report.class.default_result_extension}")
      end

      def render_report(attrs, subpath, as_json=false)
        # build report
        template_file = "#{@config.templates_folder}#{attrs['var-template']}"

        file = Tempfile.new('gf_pdf_', @config.reports_folder)
        begin
          FileUtils.chmod('+r', file.path)
        rescue StandardError => e
          @logger.debug("File permissions could not be set for #{file.path}: #{e.message}")
        end

        report = @config.report_class.new(@config)
        Thread.report_on_exception = false
        Thread.new do
          report.create_report(template_file, file, attrs)
        end
        @reports << report

        return http_response(302, 'Found', nil, Location: "#{subpath}view_report?report_id=#{report.object_id}") if not as_json

        response = {report_id: report.object_id}
        return http_response(200, 'OK', JSON.generate(response))
      end

      def get_reports_status_as_html(reports, subpath)
        i = reports.length

        # TODO: make reporter HTML results customizable
        template = <<~HTML_TEMPLATE
          <html>
          <head></head>
          <body>
          <table>
            <thead>
              <th>#</th><th>Start Time</th><th>End Time</th><th>Template</th><th>Execution time</th>
              <th>Status</th><th>Error</th><th>Action</th>
            </thead>
            <tbody>
            <% reports.reverse.map do |report| %>
              <tr><td><%= i-= 1 %></td><td><%= report.start_time %></td><td><%= report.end_time %></td>
              <td><%= report.template %></td><td><%= report.execution_time.to_i %> secs</td>
              <td><%= report.status %> (<%= (report.progress * 100).to_i %>%)</td>
              <td><%= report.error.join('<br>') %></td>
              <td><% if !report.done && !report.cancel %>
                <a href="<%= subpath %>cancel_report?report_id=<%= report.object_id %>">Cancel</a>
              <% end %>
              &nbsp;
              <% if (report.status == 'finished') || (report.status == 'cancelled') %>
                <a href="<%= subpath %>view_report?report_id=<%= report.object_id %>">View</a>
              <% end %>
              &nbsp;
              <a href="<%= subpath %>view_log?report_id=<%= report.object_id %>">Log</a></td></tr>
            <% end.join('') %>
            <tbody>
          </table>
          <p style="font-size: small; color:grey">You are running ruby-grafana-reporter version <%= GRAFANA_REPORTER_VERSION.join('.') %>.<%= @config.latest_version_check_ok? ? '' : ' Check out the latest version <a href="https://github.com/divinity666/ruby-grafana-reporter/releases/latest">here</a>.' %></p>
          </body>
          </html>
        HTML_TEMPLATE

        content = ::ERB.new(template).result(binding)

        http_response(200, 'OK', content, "Content-Type": 'text/html')
      end

      def http_response(code, text, body, opts = {})
        "HTTP/1.1 #{code} #{text}\r\n#{opts.map { |k, v| "#{k}: #{v}" }.join("\r\n")}#{opts.length > 0 ? "\r\n" : ""}"\
        "#{body ? "Content-Length: #{body.to_s.bytesize}" : ''}\r\n\r\n#{body}"
      end
    end
  end
end
