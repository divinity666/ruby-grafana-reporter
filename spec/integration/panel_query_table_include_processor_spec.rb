include GrafanaReporter::Asciidoctor::Extensions

describe PanelQueryTableIncludeProcessor do
  before do
    config = Configuration.new
    config.logger.level = ::Logger::Severity::WARN
    config.config = { 'grafana' => { 'default' => { 'host' => STUBS[:url], 'api_key' => STUBS[:key_admin]} } }
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      include_processor PanelQueryTableIncludeProcessor.new.current_report(report)
    end
    @report = report
  end

  context 'sql table' do
    it 'can return full results' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).not_to include('GrafanaReporterError')
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)).to match(/<p>\| 1594308060000 \| 43.9/)
    end

    it 'can translate times' do
      @report.logger.level = ::Logger::Severity::DEBUG
      expect(@report.logger).to receive(:debug).exactly(6).times.with(any_args)
      expect(@report.logger).to receive(:debug).with(/"from":"#{Time.utc(Time.new.year,1,1).to_i * 1000}".*"to":"#{(Time.utc(Time.new.year + 1,1,1) - 1).to_i * 1000}"/)
      expect(@report.logger).to receive(:debug).with(/Received response/)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",from_timezone=\"UTC\",to_timezone=\"UTC\",dashboard=\"#{STUBS[:dashboard]}\",from=\"now/y\",to=\"now/y\"]", to_file: false)).not_to include('GrafanaReporterError')
    end

    it 'can replace values' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",replace_values_1=\"1594308060000:geht\"]", to_file: false)).to match(/<p>\| geht \| 43.9/)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",replace_values_2=\"1594308060000:geht\"]", to_file: false)).to match(/<p>\| 1594308060000 \| 43.9/)
    end

    it 'can replace regex values' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",format=\",%.2f\",filter_columns=\"time_sec\",replace_values_2=\"^(43)\..*$:geht - \\1\"]", to_file: false)).to include('| geht - 43').and include('| 44.00')
    end

    it 'can replace values with value comparison' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",format=\",%.2f\",filter_columns=\"time_sec\",replace_values_2=\"<44:geht\"]", to_file: false)).to include('| geht').and include('| 44.00')
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",format=\",%.2f\",filter_columns=\"time_sec\",replace_values_2=\"<44:\\1 zu klein\"]", to_file: false)).to include('| 43.90 zu klein').and include('| 44.00')
    end

    it 'can filter columns' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",filter_columns=\"time_sec\"]", to_file: false)).to match(/<p>\| 43.9/)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",filter_columns=\"Warmwasser\"]", to_file: false)).to match(/<p>\| 1594308060000\n/)
    end

    it 'can format values' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",format=\",%.2f\"]", to_file: false)).to match(/<p>\| 1594308060000 \| 43.90/)
    end

    it 'handles column and row divider' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",column_divider=\" col \",row_divider=\"row \"]", to_file: false)).to match(/<p>row 1594308060000 col 43.9/)
    end

    it 'can transpose results' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",transpose=\"true\"]", to_file: false)).to match(/<p>\| 1594308060000 \| 1594308030000 \|/)
    end

    it 'shows error if a reporter error occurs' do
      expect(@report.logger).to receive(:error).with('GrafanaReporterError: The specified time range \'schwurbel\' is unknown.')
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_sql][:id]}[query=\"#{STUBS[:panel_sql][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",from=\"schwurbel\"]", to_file: false)).to include('|GrafanaReporterError: The specified time range \'schwurbel\' is unknown.')
    end

  end

  context 'graphite' do
    it 'can handle graphite requests' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_graphite][:id]}[query=\"#{STUBS[:panel_graphite][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",from=\"0\",to=\"0\"]", to_file: false)).to match(/<p>\| 27.700000000000003 \| 1617388470\n\|/)
    end
  end

  context 'prometheus' do
    it 'can handle prometheus requests' do
      expect(@report.logger).not_to receive(:error)
      expect(Asciidoctor.convert("include::grafana_panel_query_table:#{STUBS[:panel_prometheus][:id]}[query=\"#{STUBS[:panel_prometheus][:letter]}\",dashboard=\"#{STUBS[:dashboard]}\",from=\"0\",to=\"0\"]", to_file: false)).to match(/<p>\| 1617729810 \| 0.0010000000000218278\n\|/)
    end
  end
end
