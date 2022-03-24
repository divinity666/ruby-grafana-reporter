include Grafana

describe Dashboard do
  let(:dashboard) { Dashboard.new(JSON.parse(File.read('./spec/tests/demo_dashboard.json'))['dashboard'], Grafana::Grafana.new('')) }

  it 'contains panels' do
    expect(dashboard.panels.length).to eq(13)
    expect(dashboard.panel(11)).to be_a(Panel)
    expect(dashboard.panel(11).field('id')).to eq(11)
    expect(dashboard.panel(11).field('no_field_exists')).to be nil
    expect { dashboard.panel(99) }.to raise_error(PanelDoesNotExistError)
  end

  it 'contains variables' do
    expect(dashboard.variables.length).to eq(6)
    expect(dashboard.variables.select { |item| item.name == 'test' }.first.name).to eq('test')
    variable = dashboard.variables.select { |item| item.name == 'test' }.first

    expect(dashboard.from_time).to eq('now-24h')
    expect(dashboard.to_time).to be_nil
  end

  it 'can return title' do
    expect(dashboard.title).to eq("Todayd")
  end
end
