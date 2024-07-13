include GrafanaReporter

describe ReportWebhook do
    before(:context) do
      WebMock.disable_net_connect!(allow: ['http://localhost:8035'])
      config = Configuration.new
      yaml = "grafana-reporter:
  report-class: GrafanaReporter::Asciidoctor::Report
  webservice-port: 8035
  templates-folder: ./spec/tests
  reports-folder: .
  callbacks:
    http://localhost/webhook: on_after_finish

grafana:
  default:
    host: http://localhost
    api_key: #{STUBS[:key_admin]}

default-document-attributes:
  imagesdir: ."

      config.config = YAML.load(yaml)
      config.logger.level = ::Logger::Severity::WARN
      app = GrafanaReporter::Application::Application.new
      app.config = config
      @webserver = Thread.new { app.run }
      sleep 0.1 until app.webservice.running?
      @app = app
    end

    after(:context) do
      WebMock.enable!
      AbstractReport.clear_event_listeners
      # kill webservice properly and release port again
      @app.webservice.stop!
      sleep 0.1 until @app.webservice.stopped?
    end

    it 'calls event listener properly' do
      evt = ReportEventHandler.new(false)
      AbstractReport.add_event_listener(:on_after_finish, evt)

      expect(@app.config.logger).not_to receive(:error)
      url = URI('http://localhost:8035/render?var-template=demo_report')
      http = Net::HTTP.new(url.host, url.port)
      http.request_get(url.request_uri)

      cur_time = Time.new
      sleep 0.1 while !evt.done? && Time.new - cur_time < 10
      expect(evt.done?).to be true
      expect(evt.report.full_log).to include('called test webhook')
      expect(WebMock).to have_requested(:get, 'http://localhost/webhook').with(body: include('"status":"finished"'))
    end
end
