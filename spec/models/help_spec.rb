include GrafanaReporter::Asciidoctor

describe Help do
  subject { Help.new }

  it 'can build help for github' do
    result = subject.github
    expect(result).to include('grafana_panel_image')
    expect(result).to include('| --')
    expect(result).to include('Valid columns are')
  end

  it 'can build help for asciidoctor' do
    result = subject.asciidoctor
    expect(result).to include('grafana_panel_image')
    expect(result).to include('|==')
    expect(result).to include('Valid columns are')
  end
end
