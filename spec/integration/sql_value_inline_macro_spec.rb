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

  context 'sql' do
    it 'can be processed' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[sql=\"SELECT 1\"]", to_file: false)).not_to include('GrafanaReporterError')
      expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[sql=\"SELECT 1\"]", to_file: false)).to include('1')
    end

    it 'can handle errors' do
      expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[sql=\"SELECT error\"]", to_file: false)).to include('db query error')
    end

    it 'can translate times' do
      @report.logger.level = ::Logger::Severity::DEBUG
      expect(@report.logger).to receive(:debug).exactly(3).times.with(any_args)
      expect(@report.logger).to receive(:debug).with(/"from":"#{Time.utc(Time.new.year,1,1).to_i * 1000}".*"to":"#{(Time.utc(Time.new.year + 1,1,1) - 1).to_i * 1000}"/)
      expect(@report.logger).to receive(:debug).with(/Received response/)
      expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[sql=\"SELECT 1\",from=\"now/y\",to=\"now/y\",from_timezone=\"UTC\",to_timezone=\"UTC\"]", to_file: false)).not_to include('GrafanaReporterError')
    end

    it 'returns fatal error message if no sql statement specified' do
      expect(@report.logger).to receive(:error).with(/No SQL statement/)
      expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[test=\"bla\"]", to_file: false)).to include('MissingSqlQueryError')
      expect(@report.logger).to receive(:error).with(/No SQL statement/)
      expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[]", to_file: false)).to include('MissingSqlQueryError')
    end

    it 'returns error message if invalid datasource id is specified' do
      expect(@report.logger).to receive(:error).with(/Datasource/)
      expect(Asciidoctor.convert('grafana_sql_value:99[sql="SELECT 1"]', to_file: false)).to include('GrafanaError: Datasource')
    end

    it 'replaces grafana variables in sql query' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[sql=\"SELECT $my_var\"]", to_file: false, attributes: { 'var-my_var' => 1 })).to include('1')
    end

    it 'shows error if a reporter error occurs' do
      expect(@report.logger).to receive(:error).with('GrafanaReporterError: The specified time range \'schwurbel\' is unknown.')
      expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_sql]}[sql=\"SELECT 1\",from=\"schwurbel\",to=\"now/y\"]", to_file: false)).to include('GrafanaReporterError: The specified time range \'schwurbel\' is unknown.')
    end

    it 'handles standard error on internal fault' do
      obj = SqlValueInlineMacro.new.current_report(@report)
      expect(@report.logger).to receive(:fatal).with('undefined method `document\' for nil:NilClass')
      obj.process(nil, STUBS[:datasource_sql], { 'instance' => 'default' })
    end
  end

  context 'graphite' do
    it 'sorts multiple query results by time' do
      expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_graphite]}[sql=\"alias(movingAverage(scaleToSeconds(apps.fakesite.web_server_01.counters.request_status.code_302.count, 10), 20), 'cpu')\",from=\"0\",to=\"0\"]", to_file: false)).to include('1621773300000')
    end

    it 'leaves sorting as is for single query results' do
      expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_graphite]}[sql=\"alias(movingAverage(scaleToSeconds(apps.fakesite.backend_01.counters.request_status.code_302.count, 10), 20), 'cpu')\",from=\"0\",to=\"0\"]", to_file: false)).to include('1621794840000')
    end
  end

  context 'prometheus whereas closing square bracket is escaped' do
    it 'sorts multiple query results by time' do
      @report.logger.level = ::Logger::Severity::DEBUG
      allow(@report.logger).to receive(:debug)
      expect(@report.logger).to receive(:debug).with(/Translating SQL/)
      expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_prometheus]}[sql=\"sum by(mode)(irate(node_cpu_seconds_total{job=\\\"node\\\", instance=~\\\"$node:.*\\\", mode!=\\\"idle\\\"}[5m\\])) > 0\",from=\"0\",to=\"0\"]", to_file: false)).to include('1617728730')
    end

    it 'leaves sorting as is for single query results' do
      @report.logger.level = ::Logger::Severity::DEBUG
      allow(@report.logger).to receive(:debug)
      expect(@report.logger).to receive(:debug).with(/Translating SQL/)
      expect(Asciidoctor.convert("grafana_sql_value:#{STUBS[:datasource_prometheus]}[sql=\"sum by(mode)(irate(node_cpu_seconds_total{job=\\\"node\\\", instance=~\\\"$node:.*\\\", mode=\\\"iowait\\\"}[5m\\])) > 0\",from=\"0\",to=\"0\"]", to_file: false)).to include('1617728760')
    end
  end
end
