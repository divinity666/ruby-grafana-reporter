include GrafanaReporter::Asciidoctor

describe ValueAsVariableIncludeProcessor do
  before do
    config = Configuration.new
    config.logger.level = ::Logger::Severity::WARN
    config.config = { 'grafana' => { 'default' => { 'host' => STUBS[:url], 'api_key' => STUBS[:key_admin] } } }
    report = Report.new(config)
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      include_processor ValueAsVariableIncludeProcessor.new.current_report(report)
      inline_macro SqlValueInlineMacro.new.current_report(report)
      inline_macro PanelQueryValueInlineMacro.new.current_report(report)
    end
    @report = report
  end

  it 'can call inline processors' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert("include::grafana_value_as_variable[call=\"grafana_sql_value:#{STUBS[:datasource_sql]}\",sql=\"SELECT 1\",variable_name=\"test\"]", to_file: false)).not_to include('1')
    expect(Asciidoctor.convert("include::grafana_value_as_variable[call=\"grafana_sql_value:#{STUBS[:datasource_sql]}\",sql=\"SELECT 1\",variable_name=\"test\"]\n{test}", to_file: false)).to include('1')
  end

  it 'can call inline processors with global parameters' do
    expect(@report.logger).not_to receive(:error)
    expect(Asciidoctor.convert(":grafana_default_dashboard: #{STUBS[:dashboard]}\n\ninclude::grafana_value_as_variable[call=\"grafana_panel_query_value:#{STUBS[:panel_sql][:id]}\",query=\"#{STUBS[:panel_sql][:letter]}\",variable_name=\"test\"]\n{test}", to_file: false)).to include('<p>1594308060000')
  end

  it 'shows error if mandatory call attributes is missing' do
    expect(@report.logger).to receive(:error).with("ValueAsVariableIncludeProcessor: Missing mandatory attribute 'call' or 'variable_name'.")
    Asciidoctor.convert("include::grafana_value_as_variable[variable_name=\"test\",panel=\"#{STUBS[:panel_sql][:id]}\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)
  end

  it 'shows error if mandatory variable_name attributes is missing' do
    expect(@report.logger).to receive(:error).with("ValueAsVariableIncludeProcessor: Missing mandatory attribute 'call' or 'variable_name'.")
    Asciidoctor.convert("include::grafana_value_as_variable[call=\"test:1\",panel=\"#{STUBS[:panel_sql][:id]}\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)
  end

  it 'shows error if mandatory call attributes is malformed' do
    expect(@report.logger).to receive(:error).with("ValueAsVariableIncludeProcessor: Could not find inline macro extension for 'test'.")
    Asciidoctor.convert("include::grafana_value_as_variable[call=\"test\",variable_name=\"test\",panel=\"#{STUBS[:panel_sql][:id]}\",dashboard=\"#{STUBS[:dashboard]}\"]", to_file: false)
  end

  it 'shows debug message if variable is not added, as result was empty' do
    allow(@report.logger).to receive(:debug)
    expect(@report.logger).to receive(:debug).with("ValueAsVariableIncludeProcessor: Not adding variable 'test' as query result was empty.")
    Asciidoctor.convert("include::grafana_value_as_variable[call=\"grafana_sql_value:#{STUBS[:datasource_sql]}\",sql=\"SELECT 1 as value WHERE value = 0\",variable_name=\"test\"]", to_file: false)
  end
end
