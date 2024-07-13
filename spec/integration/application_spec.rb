include Grafana
include GrafanaReporter
include GrafanaReporter::Application

class ReportEventHandler
  def initialize(stop_thread = true)
    @stop_thread = stop_thread
    @done = false
  end

  def callback(event, report)
    @report = report
    case event
    when :on_before_create
      @cur_thread = Thread.current
      Thread.stop if @stop_thread

    when :on_after_finish
      @done = true
    end
  end

  def report
    @report
  end

  def unpause_thread
    @cur_thread.wakeup
  end

  def done?
    @done
  end
end

describe Application do
  context 'command line' do
    subject { GrafanaReporter::Application::Application.new }

    it 'can configure and run' do
      expect { subject.configure_and_run(['-c', './spec/tests/demo_config.txt', '--test', 'default', '-d', 'FATAL']) }.to output("Admin\n").to_stdout
    end

    it 'returns help' do
      expect { subject.configure_and_run(['--help']) }.to output(/--debug/).to_stdout
    end

    it 'can handle wrong config files' do
      expect { subject.configure_and_run(['-c', './spec/tests/demo_report.adoc']) }.to raise_error(ConfigurationError)
    end

    it 'can output version information' do
      expect { subject.configure_and_run(['-v']) }.to output(/#{GRAFANA_REPORTER_VERSION.join('.*')}/).to_stdout
    end

    it 'expects default config file' do
      expect { subject.configure_and_run(['-c', 'does_not_exist.config']) }.to output(/Config file.* does not exist/).to_stdout
    end

  end

  context 'command line single rendering' do
    subject { GrafanaReporter::Application::Application.new }

    before do
      File.delete('./result.pdf') if File.exist?('./result.pdf')
      allow(subject.config.logger).to receive(:debug)
      allow(subject.config.logger).to receive(:info)
      allow(subject.config.logger).to receive(:warn)
    end

    after do
      File.delete('./result.pdf') if File.exist?('./result.pdf')
    end

    it 'can single render a template with extension' do
      expect(subject.config.logger).not_to receive(:error)
      expect { subject.configure_and_run(['-c', './spec/tests/demo_config.txt', '-t', 'spec/tests/demo_report.adoc', '-o', './result.pdf', '-d', 'ERROR']) }.not_to output(/ERROR/).to_stderr
      expect(File.exist?('./result.pdf')).to be true
    end

    it 'can single render a template and output to custom folder' do
      expect(subject.config.logger).not_to receive(:error)
      expect { subject.configure_and_run(['-c', './spec/tests/demo_config.txt', '-t', 'spec/tests/demo_report', '-o', './result.pdf', '-d', 'ERROR']) }.not_to output(/ERROR/).to_stderr
      expect(File.exist?('./result.pdf')).to be true
    end

    it 'can accept custom command line parameters' do
      expect(subject.config.logger).to receive(:debug).with(/"par1"=>"test"/)
      expect { subject.configure_and_run(['-c', './spec/tests/demo_config.txt', '-t', 'spec/tests/demo_report', '-o', './result.pdf', '-d', 'DEBUG', '-s', 'par1,test']) }.not_to output(/ERROR/).to_stderr
    end

    it 'raises error on malformed custom command line parameters' do
      expect { subject.configure_and_run(['-c', './spec/tests/demo_config.txt', '-t', 'spec/tests/demo_report', '-o', './result.pdf', '-s', 'par1']) }.to output(/GrafanaReporterError: Parameter '-s' needs exactly two values separated by comma, received 1./).to_stdout
      expect { subject.configure_and_run(['-c', './spec/tests/demo_config.txt', '-t', 'spec/tests/demo_report', '-o', './result.pdf', '-s', 'par1,val1,something']) }.to output(/GrafanaReporterError: Parameter '-s' needs exactly two values separated by comma, received 3./).to_stdout
    end

    it 'does not raise error on non existing template' do
      expect(subject.config.logger).to receive(:error).with(/Check if file exists/)
      expect { subject.configure_and_run(['-c', './spec/tests/demo_config.txt', '-t', 'does_not_exist']) }.to output(/report template .* Check if file exists/).to_stdout
    end
  end

  context 'custom plugins' do
    subject { GrafanaReporter::Application::Application.new }

    before do
      File.delete('./result.pdf') if File.exist?('./result.pdf')
    end

    after do
      # remove temporary added plugin from respective places, so that other test cases run
      # as if that would have never happened
      expect(Object.constants.include?(:MyUnknownDatasource)).to be true
      AbstractDatasource.class_eval('@@subclasses -= [MyUnknownDatasource]')
      Object.send(:remove_const, :MyUnknownDatasource)
      Object.send(:const_set, :MyUnknownDatasource, Class.new)
    end

    it 'can register and apply custom plugins' do
      expect { subject.configure_and_run(['-c', './spec/tests/demo_config.txt', '-t', 'spec/tests/custom_demo_report', '-o', './result.pdf']) }.to output(/ERROR/).to_stderr
      expect(subject.config.logger).not_to receive(:error)
      expect { subject.configure_and_run(['-c', './spec/tests/demo_config.txt', '-t', 'spec/tests/custom_demo_report', '-o', './result.pdf', '-r', './spec/tests/custom_plugin']) }.not_to output(/ERROR/).to_stderr
      expect(Object.constants.include?(:MyUnknownDatasource)).to be true
    end
  end

  context 'ERB templating' do
    subject { GrafanaReporter::Application::Application.new }

    before :context do
      @result_folder = './spec/tmp_test_folder'
      Dir.mkdir(@result_folder) if !Dir.exist?(@result_folder)
    end

    after :context do
      Dir.rmdir(@result_folder) if Dir.exist?(@result_folder)
    end

    before do
      File.delete("#{@result_folder}/result.txt") if File.exist?("#{@result_folder}/result.txt")
      File.delete('./demo_report.erb') if File.exist?('./demo_report.erb')
      File.delete("#{@result_folder}/erb.template.txt") if File.exist?("#{@result_folder}/erb.template.txt")
      allow(subject.config.logger).to receive(:debug)
      allow(subject.config.logger).to receive(:info)
      allow(subject.config.logger).to receive(:warn)
    end

    after do
      File.delete("#{@result_folder}/result.txt") if File.exist?("#{@result_folder}/result.txt")
      File.delete('./demo_report.erb') if File.exist?('./demo_report.erb')
      File.delete("#{@result_folder}/erb.template.txt") if File.exist?("#{@result_folder}/erb.template.txt")
      #File.delete('./spec/tests/tmp_demo_report.adoc') if File.exist?('./spec/tests/tmp_demo_report.adoc')
    end

    it 'can single render a template with extension' do
      expect(subject.config.logger).not_to receive(:error)
      expect { subject.configure_and_run(['-c', './spec/tests/erb.config', '-t', 'spec/tests/erb.template', '-o', "#{@result_folder}/result.txt", '-d', 'ERROR']) }.not_to output(/ERROR/).to_stderr
      expect(File.exist?("#{@result_folder}/result.txt")).to be true
      expect(File.read("#{@result_folder}/result.txt")).to include('This is a test 1594308060000.')
    end

    it 'can single render a template without destination configured' do
      expect(subject.config.logger).not_to receive(:error)
      expect { subject.configure_and_run(['-c', './spec/tests/erb.config', '-t', 'spec/tests/erb.template', '-d', 'ERROR']) }.not_to output(/ERROR/).to_stderr
      expect(File.exist?("#{@result_folder}/erb.template.txt")).to be true
      expect(File.read("#{@result_folder}/erb.template.txt")).to include('This is a test 1594308060000.')
    end

    it 'can build and render a demo report' do
      @config = ["d\n", "y\n", "y\n"]
      config_wizard = GrafanaReporter::ConsoleConfigurationWizard.new
      allow(config_wizard).to receive(:puts)
      allow(config_wizard).to receive(:print)
      allow_any_instance_of(DemoReportWizard).to receive(:puts)
      allow_any_instance_of(DemoReportWizard).to receive(:print)
      allow(config_wizard).to receive(:gets).and_return(*@config)

      # build demo report
      config_wizard.start_wizard('./spec/tests/erb.config', Configuration.new)

      # render report
      expect(subject.config.logger).not_to receive(:error)
      expect(subject.config.logger).not_to receive(:warn)
      expect { subject.configure_and_run(['-c', './spec/tests/erb.config', '-t', 'demo_report', '-o', "#{@result_folder}/result.txt"]) }.not_to output(/ERROR/).to_stderr
      expect(File.exist?("#{@result_folder}/result.txt")).to be true
      expect(File.read("#{@result_folder}/result.txt")).to include('This is a test table for panel ')
    end
  end

  context 'webserver' do
    before(:context) do
      WebMock.disable_net_connect!(allow: ['http://localhost:8033'])
      config = Configuration.new
      yaml = "grafana-reporter:
  report-class: GrafanaReporter::Asciidoctor::Report
  webservice-port: 8033
  templates-folder: ./spec/tests
  reports-folder: .

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

    before do
      AbstractReport.clear_event_listeners
    end

    after(:context) do
      WebMock.enable!
      AbstractReport.clear_event_listeners
      # kill webservice properly and release port again
      @app.webservice.stop!
      sleep 0.1 until @app.webservice.stopped?
    end

    it 'responds to overview' do
      expect(@app.config.logger).not_to receive(:error)
      res = Net::HTTP.get(URI('http://localhost:8033/overview'))
      expect(res).to include("<th>Execution time</th>")
    end

    it 'can handle invalid web requests' do
      expect(@app.config.logger).not_to receive(:error)
      res = Net::HTTP.get(URI('http://localhost:8033/rend'))
      expect(res).to include("calls an unknown path for this webservice.")
      res = Net::HTTP.get(URI('http://localhost:8033/overview2'))
      expect(res).to include("calls an unknown path for this webservice")
    end

    it 'can properly cancel demo report' do
      evt = ReportEventHandler.new
      AbstractReport.add_event_listener(:on_before_create, evt)
      AbstractReport.add_event_listener(:on_after_finish, evt)

      expect(@app.config.logger).not_to receive(:error)
      url = URI('http://localhost:8033/render?var-template=demo_report')
      http = Net::HTTP.new(url.host, url.port)
      res = http.request_get(url.request_uri)
      expect(res.code).to eq("302")
      expect(res['location']).to include("/view_report?report_id=")

      id = res['location'].gsub(/.*report_id=([^\r\n]*).*/, '\1')
      res = http.request_get("/view_report?report_id=#{id}")
      expect(res.body).to include("not started")
      res = http.request_get("/cancel_report?report_id=#{id}")
      expect(res.code).to eq("302")

      evt.unpause_thread
      cur_time = Time.new
      sleep 0.1 while !evt.done? && Time.new - cur_time < 10

      res = Net::HTTP.get(URI("http://localhost:8033/view_log?report_id=#{id}"))
      expect(res).to include("Cancelling report generation invoked.")
      res = Net::HTTP.get(URI('http://localhost:8033/overview'))
      expect(res).to include(id)
      expect(evt.done?).to be true
    end

    it 'can properly create demo pdf report' do
      evt = ReportEventHandler.new
      AbstractReport.add_event_listener(:on_before_create, evt)
      AbstractReport.add_event_listener(:on_after_finish, evt)

      expect(@app.config.logger).not_to receive(:error)
      url = URI('http://localhost:8033/render?var-template=demo_report')
      http = Net::HTTP.new(url.host, url.port)
      res = http.request_get(url.request_uri)
      expect(res.code).to eq("302")
      expect(res['location']).to include("/view_report?report_id=")

      id = res['location'].gsub(/.*report_id=([^\r\n]*).*/, '\1')
      res = http.request_get("/view_report?report_id=#{id}")
      expect(res.body).to include("not started")
      res = http.request_get("/view_log?report_id=#{id}")
      expect(res.body).not_to include("Cancelling report generation invoked.")
      res = http.request_get('/overview')
      expect(res.body).to include(id)

      evt.unpause_thread
      cur_time = Time.new
      sleep 0.1 while !evt.done? && Time.new - cur_time < 10
      expect(evt.done?).to be true

      res = http.request_get("/view_report?report_id=#{id}")
      expect(res['content-type']).to include('application/pdf')
    end

    it 'can properly create demo html report' do
      evt = ReportEventHandler.new
      AbstractReport.add_event_listener(:on_before_create, evt)
      AbstractReport.add_event_listener(:on_after_finish, evt)

      expect(@app.config.logger).not_to receive(:error)
      url = URI('http://localhost:8033/render?var-template=demo_report&convert-backend=html')
      http = Net::HTTP.new(url.host, url.port)
      res = http.request_get(url.request_uri)
      expect(res.code).to eq("302")
      expect(res['location']).to include("/view_report?report_id=")

      id = res['location'].gsub(/.*report_id=([^\r\n]*).*/, '\1')
      res = http.request_get("/view_report?report_id=#{id}")
      expect(res.body).to include("not started")
      res = http.request_get("/view_log?report_id=#{id}")
      expect(res.body).not_to include("Cancelling report generation invoked.")
      res = http.request_get('/overview')
      expect(res.body).to include(id)

      evt.unpause_thread
      cur_time = Time.new
      sleep 0.1 while !evt.done? && Time.new - cur_time < 10
      expect(evt.done?).to be true

      res = http.request_get("/view_report?report_id=#{id}")
      expect(res['content-type']).to include('application/octet-stream')
      expect(res['content-disposition']).to include('.zip')
    end

    it 'can create demo html report if called with other top level domain' do
      evt = ReportEventHandler.new
      AbstractReport.add_event_listener(:on_before_create, evt)
      AbstractReport.add_event_listener(:on_after_finish, evt)

      expect(@app.config.logger).not_to receive(:error)
      url = URI('http://localhost:8033/reporter_path/render?var-template=demo_report&convert-backend=html')
      http = Net::HTTP.new(url.host, url.port)
      res = http.request_get(url.request_uri)
      expect(res.code).to eq("302")
      expect(res['location']).to include("/reporter_path/view_report?report_id=")

      id = res['location'].gsub(/.*report_id=([^\r\n]*).*/, '\1')
      res = http.request_get("/reporter_path/view_report?report_id=#{id}")
      expect(res.body).to include("not started")
      res = http.request_get("/reporter_path/view_log?report_id=#{id}")
      expect(res.body).not_to include("Cancelling report generation invoked.")
      res = http.request_get('/reporter_path/overview')
      expect(res.body).to include(id)

      evt.unpause_thread
      cur_time = Time.new
      sleep 0.1 while !evt.done? && Time.new - cur_time < 10
      expect(evt.done?).to be true

      res = http.request_get("/reporter_path/view_report?report_id=#{id}")
      expect(res['content-type']).to include('application/octet-stream')
      expect(res['content-disposition']).to include('.zip')
    end

    it 'returns grafana reporter error on view_log without report' do
      expect(@app.config.logger).to receive(:error).with(/has been called without valid id/)
      expect(Net::HTTP.get(URI('http://localhost:8033/view_log'))).to include('has been called without valid id')
    end

    it 'returns error on render without template' do
      evt = ReportEventHandler.new
      AbstractReport.add_event_listener(:on_after_finish, evt)

      expect_any_instance_of(GrafanaReporter::Logger::TwoWayDelegateLogger).to receive(:error).with(/Check if file exists/)
      res = Net::HTTP.get(URI('http://localhost:8033/render'))
      cur_time = Time.new
      sleep 0.1 while !evt.done? && Time.new - cur_time < 10
    end

    it 'returns error on render with non existing template' do
      evt = ReportEventHandler.new
      AbstractReport.add_event_listener(:on_after_finish, evt)

      expect_any_instance_of(GrafanaReporter::Logger::TwoWayDelegateLogger).to receive(:error).with(/Check if file exists/)
      res = Net::HTTP.get(URI('http://localhost:8033/render?var-template=does_not_exist'))
      cur_time = Time.new
      sleep 0.1 while !evt.done? && Time.new - cur_time < 10
    end
  end

  context 'API server' do
    before(:context) do
      WebMock.disable_net_connect!(allow: ['http://localhost:8034'])
      config = Configuration.new
      yaml = "grafana-reporter:
  report-class: GrafanaReporter::Asciidoctor::Report
  webservice-port: 8034
  templates-folder: ./spec/tests
  reports-folder: .

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

    before do
      AbstractReport.clear_event_listeners
    end

    after(:context) do
      WebMock.enable!
      AbstractReport.clear_event_listeners
      # kill webservice properly and release port again
      @app.webservice.stop!
      sleep 0.1 until @app.webservice.stopped?
    end

    it 'renders report properly' do
      evt = ReportEventHandler.new

      expect(@app.config.logger).not_to receive(:error)
      res = Net::HTTP.post(URI('http://localhost:8034/api/v1/render?var-template=demo_report'), nil)
      expect(res.code).to eq("200")
      json = JSON.parse(res.body)

      cur_time = Time.new
      sleep 0.1 while !evt.done? && Time.new - cur_time < 10

      url = URI("http://localhost:8034/api/v1/status?report_id=#{json['report_id']}")
      http = Net::HTTP.new(url.host, url.port)
      res = http.request_get(url)
      expect(res.code).to eq("200")
      json = JSON.parse(res.body)
      expect(res['Content-Type']).to eq("application/json")
      expect(json['state']).to eq("finished")
      expect(json['progress']).to eq(1)
      expect(json['done']).to eq(true)
      expect(json['execution_time']).to be_a(Float)
    end

    it 'allows report creation, cancel and status' do
      evt = ReportEventHandler.new
      AbstractReport.add_event_listener(:on_before_create, evt)
      AbstractReport.add_event_listener(:on_after_finish, evt)

      expect(@app.config.logger).not_to receive(:error)
      res = Net::HTTP.post(URI('http://localhost:8034/api/v1/render?var-template=demo_report'), nil)
      expect(res.code).to eq("200")
      json = JSON.parse(res.body)
      expect(json['report_id']).to be_an(Integer)

      url = URI("http://localhost:8034/api/v1/status?report_id=#{json['report_id']}")
      http = Net::HTTP.new(url.host, url.port)
      res = http.request_get(url)
      expect(res.code).to eq("200")
      json = JSON.parse(res.body)
      expect(res['Content-Type']).to eq("application/json")
      expect(json['report_id']).to be_an(Integer)
      expect(json['state']).to eq("not started")
      expect(json['progress']).to eq(0)
      expect(json['done']).to eq(false)
      expect(json['execution_time']).to eq(nil)

      res = http.delete(URI("http://localhost:8034/api/v1/cancel?report_id=#{json['report_id']}"))
      expect(res.code).to eq("200")

      evt.unpause_thread
      cur_time = Time.new
      sleep 0.1 while !evt.done? && Time.new - cur_time < 10

      url = URI("http://localhost:8034/api/v1/status?report_id=#{json['report_id']}")
      http = Net::HTTP.new(url.host, url.port)
      res = http.request_get(url)
      expect(res.code).to eq("200")
      json = JSON.parse(res.body)
      expect(res['Content-Type']).to eq("application/json")
      expect(json['state']).to eq("cancelled")
      expect(json['progress']).to eq(0)
      expect(json['done']).to eq(true)
      expect(json['execution_time']).to be_a(Float)

      expect(evt.done?).to be true
    end

  end
end
