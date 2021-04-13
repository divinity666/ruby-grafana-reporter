include GrafanaReporter::Asciidoctor

describe ShowHelpIncludeProcessor do
  before do
    config = Configuration.new
    config.logger.level = ::Logger::Severity::WARN
    config.config = { 'grafana' => { 'default' => { 'host' => STUBS[:url], 'api_key' => STUBS[:key_admin] } } }
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      include_processor ShowHelpIncludeProcessor.new.current_report(report)
    end
    @report = report
  end

  it 'can be processed' do
    expect(@report.logger).not_to receive(:error)
    result = Asciidoctor.convert('include::grafana_help[]', to_file: false)
    expect(result).not_to include('GrafanaReporterError')
    expect(result).to include('grafana_panel_image')
  end
end
