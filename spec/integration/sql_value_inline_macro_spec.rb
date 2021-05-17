include GrafanaReporter::Asciidoctor

describe SqlValueInlineMacro do
  before do
    config = Configuration.new
    config.logger.level = ::Logger::Severity::WARN
    config.config = { 'grafana' => { 'default' => { 'host' => STUBS[:url], 'api_key' => STUBS[:key_admin] } } }
    report = Report.new(config)
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      inline_macro SqlValueInlineMacro.new.current_report(report)
    end
    @report = report
  end

  it 'can be processed' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[sql=\"SELECT 1\"]", to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[sql=\"SELECT 1\"]", to_file: false)).to include('1')
  end

  it 'can translate times' do
    @report.logger.level = ::Logger::Severity::DEBUG
    expect(@report.logger).to receive(:debug).exactly(4).times.with(any_args)
    expect(@report.logger).to receive(:debug).with(/"from":"#{Time.utc(Time.new.year,1,1).to_i * 1000}".*"to":"#{(Time.utc(Time.new.year + 1,1,1) - 1).to_i * 1000}"/)
    expect(@report.logger).to receive(:debug).with(/Received response/)
    expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[sql=\"SELECT 1\",from=\"now/y\",to=\"now/y\",from_timezone=\"UTC\",to_timezone=\"UTC\"]", to_file: false)).not_to include('GrafanaReporterError')
  end

  it 'returns fatal error message if no sql statement specified' do
    expect(@report.logger).to receive(:fatal).with(/No SQL statement/)
    expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[test=\"bla\"]", to_file: false)).to include('MissingSqlQueryError')
    expect(@report.logger).to receive(:fatal).with(/No SQL statement/)
    expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[]", to_file: false)).to include('MissingSqlQueryError')
  end

  it 'returns error message if invalid datasource id is specified' do
    expect(@report.logger).to receive(:fatal).with(/Datasource/)
    expect(Asciidoctor.convert('grafana_sql_value:99[sql="SELECT 1"]', to_file: false)).to include('GrafanaError: Datasource')
  end

  it 'replaces grafana variables in sql query' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[sql=\"SELECT $my-var\"]", to_file: false, attributes: { 'var-my-var' => 1 })).to include('1')
  end

  it 'shows error if a reporter error occurs' do
    expect(@report.logger).to receive(:error).with('GrafanaReporterError: The specified time range \'schwurbel\' is unknown.')
    expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[sql=\"SELECT 1\",from=\"schwurbel\",to=\"now/y\"]", to_file: false)).to include('GrafanaReporterError: The specified time range \'schwurbel\' is unknown.')
  end

end
