# frozen_string_literal: true

module GrafanaReporter
  class ReportWebhook
    def initialize(callback_url)
      @callback_url = callback_url
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
      # build report information as JSON
      data = {object_id: report.object_id, path: report.path, status: report.status,
              execution_time: report.execution_time, template: report.template,
              start_time: report.start_time, end_time: report.end_time}

      res = ::Grafana::WebRequest.new(@callback_url, {body: JSON.generate(data), accept: nil, content_type: nil}).execute
      "#{res} - Body: #{res.body}"
    end
  end
end
