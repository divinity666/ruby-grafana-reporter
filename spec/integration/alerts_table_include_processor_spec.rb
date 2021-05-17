include GrafanaReporter::Asciidoctor

describe AlertsTableIncludeProcessor do
  before do
    config = Configuration.new
    config.logger.level = ::Logger::Severity::WARN
    config.config = { 'grafana' => { 'default' => { 'host' => STUBS[:url], 'api_key' => STUBS[:key_admin] } } }
    report = Report.new(config)
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      include_processor AlertsTableIncludeProcessor.new.current_report(report)
    end
    @report = report
  end

  it 'can be processed' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("include::grafana_alerts[columns=\"newStateDate,name,state\",panel=\"#{STUBS[:panel_sql][:id]}\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert("include::grafana_alerts[columns=\"newStateDate,name,state\",panel=\"#{STUBS[:panel_sql][:id]}\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).to include('Panel Title alert')
  end

  it 'shows error if unknown columns are specified' do
    expect(@report.logger).to receive(:error).with(/key not found: "stated"/)
    expect(Asciidoctor.convert("include::grafana_alerts[columns=\"newStateDate,name,stated\",panel=\"#{STUBS[:panel_sql][:id]}\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).to include('key')
  end

end
