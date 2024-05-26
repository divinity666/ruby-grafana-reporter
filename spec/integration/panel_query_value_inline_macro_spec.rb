include GrafanaReporter::Asciidoctor

describe PanelQueryValueInlineMacro do
  before do
    config = Configuration.new
    config.logger.level = ::Logger::Severity::WARN
    config.config = { 'grafana' => { 'default' => { 'host' => STUBS[:url], 'api_key' => STUBS[:key_admin] } } }
    report = Report.new(config)
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      inline_macro PanelQueryValueInlineMacro.new.current_report(report)
    end
    @report = report
  end

  it 'can be processed' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).to include('<p>1594308060000')
  end

  it 'can translate times' do
    @report.logger.level = ::Logger::Severity::DEBUG
    expect(@report.logger).to receive(:debug).with(/Processing PanelQueryValueInlineMacro/)
    #expect(@report.logger).to receive(:debug).exactly(5)
    allow(@report.logger).to receive(:debug)
    expect(@report.logger).to receive(:debug).with(/Requesting.*"from":"#{Time.utc(Time.new.year,1,1).to_i * 1000}".*"to":"#{(Time.utc(Time.new.year + 1,1,1) - 1).to_i * 1000}"/).exactly(:once)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[from_timezone=\"UTC\",to_timezone=\"UTC\",query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",from=\"now/y\",to=\"now/y\"]", to_file: false)).not_to include('GrafanaReporterError')
  end

  it 'can replace values' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",replace_values_1=\"1594308060000:geht\"]", to_file: false)).to include('<p>geht')
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",replace_values_2=\"1594308060000:geht\"]", to_file: false)).to include('<p>1594308060000')
  end

  it 'can replace value with proper escaped colons' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",replace_values_1=\"" + '159430\:8060000\::ge\:ht' + '"]', to_file: false)).not_to include('The specified replace_values statement')
  end

  it 'raises error on replace_values without unescaped colon' do
    expect(@report.logger).to receive(:error).with(/The specified replace_values statement/)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",replace_values_1=\"" + '159430\:8060000\:\:ge\:ht' + '"]', to_file: false)).to include('The specified replace_values statement')
  end

  it 'raises error on replace_values with multiple unescaped colons' do
    expect(@report.logger).to receive(:error).with(/The specified replace_values statement/)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",replace_values_1=\"" + '159430:8060000:\:ge\:ht' + '"]', to_file: false)).to include('The specified replace_values statement')
  end

  it 'can filter columns' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",filter_columns=\"time_sec\"]", to_file: false)).to include('<p>43.9')
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",filter_columns=\"Warmwasser\"]", to_file: false)).to include('<p>1594308060000')
  end

  it 'can apply select_value first' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",filter_columns=\"time_sec\",select_value=\"first\"]", to_file: false)).to include('<p>43.9')
  end

  it 'can apply select_value last' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",filter_columns=\"time_sec\",select_value=\"last\"]", to_file: false)).to include('<p>40.9')
  end

  it 'can apply select_value min' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",filter_columns=\"time_sec\",select_value=\"min\"]", to_file: false)).to include('<p>40')
  end

  it 'can apply select_value max' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",filter_columns=\"time_sec\",select_value=\"max\"]", to_file: false)).to include('<p>45')
  end

  it 'can apply select_value avg' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",filter_columns=\"time_sec\",select_value=\"avg\"]", to_file: false)).to include('<p>43.33405797101')
  end

  it 'can apply select_value sum' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",filter_columns=\"time_sec\",select_value=\"sum\"]", to_file: false)).to include('<p>29900.5')
  end

  it 'raises error if unknown select_value is provided' do
    expect(@report.logger).to receive(:error).with(include("Unsupported 'select_value' specified in template file")).at_least(:once)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",filter_columns=\"time_sec\",select_value=\"unknown\"]", to_file: false)).to include("<p>GrafanaReporterError: Unsupported 'select_value' specified in template file")
  end

  it 'can filter columns and format values' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",format=\",%.2f\",filter_columns=\"time_sec\"]", to_file: false)).to include('<p>43.90')
  end

  it 'can filter columns and handle wront format definitions' do
    expect(@report.logger).to receive(:error).with('invalid format character - %').at_least(:once)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",format=\",%2%2f\",filter_columns=\"time_sec\"]", to_file: false)).to include('<p>invalid format character')
  end

  it 'shows fatal error if query is missing' do
    expect(@report.logger).to receive(:error).with(/GrafanaError: The specified query '' does not exist in the panel '11' in dashboard.*/)
    expect(Asciidoctor.convert("grafana_panel_query_value:#{STUBS[:panel_sql][:id]}[dashboard=\"#{STUBS[:dashboard]}\",format=\",%.2f\",filter_columns=\"time_sec\"]", to_file: false)).to include('GrafanaError: The specified query \'\' does not exist in the panel \'11\' in dashboard')
  end

  it 'handles standard error on internal fault' do
    obj = PanelQueryValueInlineMacro.new.current_report(@report)
    expect(@report.logger).to receive(:fatal).with(include('undefined method `document\' for nil'))
    obj.process(nil, STUBS[:panel_sql][:id], { 'instance' => 'default', 'dashboard' => STUBS[:dashboard] })
  end
end
