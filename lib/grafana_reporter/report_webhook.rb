# frozen_string_literal: true

module GrafanaReporter
  class ReportWebhook
    def initialize(callback_url)
      @callback_uri = URI.parse(callback_url)
    end

    # Implements the call of the configured webhook.
    # Provides the following report information in JSON format:
    #
    # +object_id+ - id of the current report
    # +path+ - file path to the report
    # +status+ - report status as string, e.g. +cancelled+, +finished+ or +in progress+
    # +execution_time+ - execution time of the report
    # +template+ - name of the used template
    # +start_time+ - time when the report creation started
    # +end_time+ - time when the report creation ended
    def callback(event, report)
      http = Net::HTTP.new(@callback_uri.host, @callback_uri.port)
      http.read_timeout = 5
      request = Net::HTTP::Get.new(@callback_uri.request_uri)

      # build report information as JSON
      data = {object_id: report.object_id, path: report.path, status: report.status,
              execution_time: report.execution_time, template: report.template,
              start_time: report.start_time, end_time: report.end_time}
      request.body = JSON.generate(data)

      # TODO: also add HTTPS webhook support
      res = http.request(request)
      "#{res} - Body: #{res.body}"
    end
  end
end
