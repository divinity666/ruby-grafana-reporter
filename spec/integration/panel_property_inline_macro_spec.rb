include GrafanaReporter::Asciidoctor

describe PanelPropertyInlineMacro do
  before do
    config = Configuration.new
    config.logger.level = ::Logger::Severity::WARN
    config.config = { 'grafana' => { 'default' => { 'host' => STUBS[:url], 'api_key' => STUBS[:key_admin]} } }
    report = Report.new(config)
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      inline_macro PanelPropertyInlineMacro.new.current_report(report)
    end
    @report = report
  end

  it 'can be processed' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_property:#{STUBS[:panel_sql][:id]}[\"title\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).not_to include('GrafanaError')
    expect(Asciidoctor.convert("grafana_panel_property:#{STUBS[:panel_sql][:id]}[\"title\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).to include(STUBS[:panel_sql][:title])
  end

  it 'replaces grafana variables in result' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_property:#{STUBS[:panel_sql][:id]}[\"description\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false, attributes: { 'var-my-var' => 'Meine Ersetzung' })).to include('Meine Ersetzung')
  end

  it 'raises error on non existring panel' do
    expect(@report.logger).to receive(:fatal)
    expect(Asciidoctor.convert("grafana_panel_property:50[\"description\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).to include('Error')
  end

end
