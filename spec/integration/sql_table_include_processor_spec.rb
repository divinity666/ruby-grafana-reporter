include GrafanaReporter::Asciidoctor

describe SqlTableIncludeProcessor do
  before do
    config = Configuration.new
    config.logger.level = ::Logger::Severity::WARN
    config.config = { 'grafana' => { 'default' => { 'host' => STUBS[:url], 'api_key' => STUBS[:key_admin] } } }
    report = Report.new(config)
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      include_processor SqlTableIncludeProcessor.new.current_report(report)
    end
    @report = report
  end

  context 'sql' do
    it 'can be processed' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("include::grafana_sql_table:#{STUBS[:datasource_sql]}[sql=\"SELECT 1\"]", to_file: false)).not_to include('GrafanaReporterError')
    end

    it 'can translate times' do
      @report.logger.level = ::Logger::Severity::DEBUG
      expect(@report.logger).to receive(:debug).exactly(3).times.with(any_args)
      expect(@report.logger).to receive(:debug).with(/"from":"#{Time.utc(Time.new.year,1,1).to_i * 1000}".*"to":"#{(Time.utc(Time.new.year + 1,1,1) - 1).to_i * 1000}"/)
      expect(@report.logger).to receive(:debug).with(/Received response/)
      expect(Asciidoctor.convert("include::grafana_sql_table:#{STUBS[:datasource_sql]}[sql=\"SELECT 1\",from_timezone=\"UTC\",to_timezone=\"UTC\",from=\"now/y\",to=\"now/y\"]", to_file: false)).not_to include('GrafanaReporterError')
    end

    it 'shows fatal error if sql statement is missing' do
      expect(@report.logger).to receive(:error).with("GrafanaError: No SQL statement has been specified. (Grafana::MissingSqlQueryError)")
      expect(Asciidoctor.convert("include::grafana_sql_table:#{STUBS[:datasource_sql]}[from=\"now/y\",to=\"now/y\"]", to_file: false)).to include('GrafanaError: No SQL statement has been specified. (Grafana::MissingSqlQueryError)')
    end

    it 'shows error if a reporter error occurs' do
      expect(@report.logger).to receive(:error).with('GrafanaReporterError: The specified time range \'schwurbel\' is unknown.')
      expect(Asciidoctor.convert("include::grafana_sql_table:#{STUBS[:datasource_sql]}[sql=\"SELECT 1\",from=\"schwurbel\",to=\"now/y\"]", to_file: false)).to include('|GrafanaReporterError: The specified time range \'schwurbel\' is unknown.')
    end

    it 'handles standard error on internal fault' do
      obj = SqlTableIncludeProcessor.new.current_report(@report)
      class MyReader; def unshift_line(*args); end; end
      expect(@report.logger).to receive(:fatal).with('undefined method `attributes\' for nil:NilClass')
      obj.process(nil, MyReader.new, ":#{STUBS[:datasource_sql]}", { 'instance' => 'default' })
    end
  end

  context 'influx' do
    it 'sorts multiple query results by time' do
      expect(Asciidoctor.convert("include::grafana_sql_table:#{STUBS[:datasource_influx]}[sql=\"SELECT non_negative_derivative(mean(\\\"value\\\"), 10s) *1000000000 FROM \\\"logins.count\\\" WHERE time >= 0ms and time <= 0ms GROUP BY time(0s), \\\"hostname\\\" fill(null)\"]", to_file: false)).to include("<p>\| 1621781110000 \| 4410823132.66179 \| 3918217168.1713953 \| 696149370.0246137 \| 308698357.77230036 \|  \| 2069259154.5448523 \| 1037231406.781757 \| 2008807302.9000952 \| 454762299.1667595 \| 1096524688.048703\n\|")
    end

    it 'leaves sorting as is for single query results' do
      expect(Asciidoctor.convert("include::grafana_sql_table:#{STUBS[:datasource_influx]}[sql=\"SELECT non_negative_derivative(mean(\\\"value\\\"), 10s) *1000000000 FROM \\\"logins.count\\\" WHERE time >= 0ms AND \\\"hostname\\\" = \\\"10.1.0.100.1\\\" GROUP BY time(10s) fill(null)\"]", to_file: false)).to include("<p>\| 1621781130000 \| 2834482201.7361364\n\|")
    end

    it 'can replace interval variable with given step' do
      @report.logger.level = ::Logger::Severity::DEBUG
      allow(@report.logger).to receive(:debug)
      expect(@report.logger).to receive(:debug).with(/GROUP%20BY%20time%281m%29/)
      Asciidoctor.convert("include::grafana_sql_table:#{STUBS[:datasource_influx]}[sql=\"SELECT non_negative_derivative(mean(\\\"value\\\"), 10s) *1000000000 FROM \\\"logins.count\\\" WHERE time >= 0ms AND \\\"hostname\\\" = \\\"10.1.0.100.1\\\" GROUP BY time($__interval) fill(null)\",step=\"1m\",from=\"now-10h\",to=\"now\"]", to_file: false)
    end

    it 'can replace interval variable with default step' do
      @report.logger.level = ::Logger::Severity::DEBUG
      allow(@report.logger).to receive(:debug)
      expect(@report.logger).to receive(:debug).with(/GROUP%20BY%20time%2835s%29/)
      Asciidoctor.convert("include::grafana_sql_table:#{STUBS[:datasource_influx]}[sql=\"SELECT non_negative_derivative(mean(\\\"value\\\"), 10s) *1000000000 FROM \\\"logins.count\\\" WHERE time >= 0ms AND \\\"hostname\\\" = \\\"10.1.0.100.1\\\" GROUP BY time($__interval) fill(null)\",from=\"now-10h\",to=\"now\"]", to_file: false)
    end

    it 'can replace interval variable with default step in ms' do
      @report.logger.level = ::Logger::Severity::DEBUG
      allow(@report.logger).to receive(:debug)
      expect(@report.logger).to receive(:debug).with(/GROUP%20BY%20time%2835999%29/)
      Asciidoctor.convert("include::grafana_sql_table:#{STUBS[:datasource_influx]}[sql=\"SELECT non_negative_derivative(mean(\\\"value\\\"), 10s) *1000000000 FROM \\\"logins.count\\\" WHERE time >= 0ms AND \\\"hostname\\\" = \\\"10.1.0.100.1\\\" GROUP BY time($__interval_ms) fill(null)\",from=\"now-10h\",to=\"now\"]", to_file: false)
    end
  end

  context 'prometheus' do
    it 'sorts multiple query results by time' do
      expect(Asciidoctor.convert("include::grafana_sql_table:#{STUBS[:datasource_prometheus]}[sql=\"sum by(mode)(irate(node_cpu_seconds_total{job=\\\"node\\\", instance=~\\\"$node:.*\\\", mode!=\\\"idle\\\"}[5m])) > 0\",from=\"0\",to=\"0\",step=\"10\"]", to_file: false)).to include('<p>| 1617728730')
    end

    it 'leaves sorting as is for single query results' do
      expect(Asciidoctor.convert("include::grafana_sql_table:#{STUBS[:datasource_prometheus]}[sql=\"sum by(mode)(irate(node_cpu_seconds_total{job=\\\"node\\\", instance=~\\\"$node:.*\\\", mode=\\\"iowait\\\"}[5m])) > 0\",from=\"0\",to=\"0\"]", to_file: false)).to include('<p>| 1617728760')
    end
  end
end
