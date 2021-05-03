include GrafanaReporter::Asciidoctor

describe AnnotationsTableIncludeProcessor do
  before do
    config = Configuration.new
    config.logger.level = ::Logger::Severity::WARN
    config.config = { 'grafana' => { 'default' => { 'host' => STUBS[:url], 'api_key' => STUBS[:key_admin] } } }
    report = Report.new(config)
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      include_processor AnnotationsTableIncludeProcessor.new.current_report(report)
    end
    @report = report
  end

  it 'can be processed if panel and dashboard is given' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("include::grafana_annotations[columns=\"time,id,alertName\",panel=\"#{STUBS[:panel_sql][:id]}\",dashboard=\"#{STUBS[:dashboard]}\",from=\"0\",to=\"0\"]", to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert("include::grafana_annotations[columns=\"time,id,alertName\",panel=\"#{STUBS[:panel_sql][:id]}\",dashboard=\"#{STUBS[:dashboard]}\",from=\"0\",to=\"0\"]", to_file: false)).to include('Panel Title alert')
    expect(WebMock).to have_requested(:get, "http://localhost/api/annotations?dashboardId=#{STUBS[:dashboard]}&panelId=#{STUBS[:panel_sql][:id]}&from=0&to=0").twice
  end

  it 'can be processed if dashboard is given' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("include::grafana_annotations[columns=\"time,id,alertName\",dashboard=\"#{STUBS[:dashboard]}\",from=\"0\",to=\"0\"]", to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert("include::grafana_annotations[columns=\"time,id,alertName\",dashboard=\"#{STUBS[:dashboard]}\",from=\"0\",to=\"0\"]", to_file: false)).to include('Panel Title alert')
    expect(WebMock).to have_requested(:get, "http://localhost/api/annotations?dashboardId=#{STUBS[:dashboard]}&from=0&to=0").twice
  end

  it 'can be processed without dashboard and panel' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("include::grafana_annotations[columns=\"time,id,alertName\",from=\"0\",to=\"0\"]", to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert("include::grafana_annotations[columns=\"time,id,alertName\",from=\"0\",to=\"0\"]", to_file: false)).to include('Panel Title alert')
    expect(WebMock).to have_requested(:get, "http://localhost/api/annotations?from=0&to=0").twice
  end

  it 'shows error if unknown columns are specified' do
    expect(@report.logger).to receive(:error).with(/key/)
    expect(Asciidoctor.convert("include::grafana_annotations[columns=\"time,id,alert_name\",panel=\"#{STUBS[:panel_sql][:id]}\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).to include('key')
  end

  it 'shows error if columns attribute is missing' do
    expect(@report.logger).to receive(:error).with(/Missing mandatory attribute 'columns'/)
    expect(Asciidoctor.convert("include::grafana_annotations[panel=\"#{STUBS[:panel_sql][:id]}\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).to include("Missing mandatory attribute 'columns'.")
  end

  it 'shows error if time range is unknown' do
    expect(@report.logger).to receive(:error).with(/The specified time range/)
    expect(Asciidoctor.convert("include::grafana_annotations[columns=\"time,id,alert_name\",panel=\"#{STUBS[:panel_sql][:id]}\",dashboard=\"#{STUBS[:dashboard]}\",from=\"unknown\"]", to_file: false)).to include('The specified time range')
  end
end
