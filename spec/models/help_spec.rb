include GrafanaReporter::Asciidoctor

describe Help do
  subject { GrafanaReporter::Asciidoctor::Help.new }

  it 'can build help for github' do
    result = subject.github
    expect(result).to include('grafana_panel_image')
    expect(result).to include('| --')
  end

  it 'can build help for asciidoctor' do
    result = subject.asciidoctor
    expect(result).to include('grafana_panel_image')
    expect(result).to include('|==')
  end
end
