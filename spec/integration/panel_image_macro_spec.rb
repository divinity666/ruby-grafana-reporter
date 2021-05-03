include GrafanaReporter::Asciidoctor

describe PanelImageBlockMacro do
  before do
    config = Configuration.new
    config.logger.level = ::Logger::Severity::WARN
    config.config = { 'grafana' => { 'default' => { 'host' => STUBS[:url], 'api_key' => STUBS[:key_admin] } } }
    report = Report.new(config)
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      block_macro PanelImageBlockMacro.new.current_report(report)
    end
    @report = report
  end

  it 'can be processed' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_image::#{STUBS[:panel_sql][:id]}[dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).to include('<img src="gf_image_').and match(/(?!Error)/)
  end

  it 'can be processed for datasources with unknown type' do
    expect(@report.logger).not_to receive(:error)
    expect(@report.logger).not_to receive(:warn)
    expect(Asciidoctor.convert("grafana_panel_image::#{STUBS[:panel_ds_unknown][:id]}[dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).to include('<img src="gf_image_').and match(/(?!Error)/)
  end

  it 'shows errors properly if panel is unknown' do
    expect(@report.logger).to receive(:fatal)
    expect(Asciidoctor.convert("grafana_panel_image::999[dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).to include('Error')
  end
end

describe PanelImageInlineMacro do
  before do
    config = Configuration.new
    config.config = { 'grafana' => { 'default' => { 'host' => STUBS[:url], 'api_key' => STUBS[:key_admin] } } }
    config.logger.level = ::Logger::Severity::WARN
    report = Report.new(config)
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      inline_macro PanelImageInlineMacro.new.current_report(report)
    end
    @report = report
  end

  it 'retrieves images properly' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_image:#{STUBS[:panel_sql][:id]}[dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).to include('<img src="gf_image_').and match(/(?!Error)/)
  end

  it 'cleans up created temporary files' do
    expect(@report.logger).not_to receive(:error)
    ts = Time.now.to_s
    result = Asciidoctor.convert("grafana_panel_image:#{STUBS[:panel_sql][:id]}[dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false, attributes: { 'grafana-report-timestamp' => ts })
    tmp_file = result.to_s.gsub(/.*img src="([^"]+)".*/m, '\1')
# TODO: ensure that the file existed before
    expect(File.exist?("./spec/templates/images/#{tmp_file}")).to be false
  end

  it 'shows error if a reporter error occurs' do
    expect(@report.logger).to receive(:error).with('GrafanaReporterError: The specified time range \'schwurbel\' is unknown.')
    expect(Asciidoctor.convert("grafana_panel_image:#{STUBS[:panel_sql][:id]}[dashboard=\"#{STUBS[:dashboard]}\",from=\"schwurbel\"]", to_file: false)).to include('GrafanaReporterError: The specified time range \'schwurbel\' is unknown.')
  end

end
