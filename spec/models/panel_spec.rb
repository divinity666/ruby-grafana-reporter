include Grafana

describe Panel do
  let(:panel) { Dashboard.new(JSON.parse(File.read('./spec/tests/demo_dashboard.json'))['dashboard'], Grafana::Grafana.new('')).panel(11) }

  it 'contains proper field values' do
    expect(panel.field('title')).to eq('Temperaturen')
  end

  it 'can return queries properly' do
    expect(panel.query('D')).to be_a(String)
    expect { panel.query('Z') }.to raise_error(QueryLetterDoesNotExistError)
    expect { panel.query(nil) }.to raise_error(QueryLetterDoesNotExistError)
  end

  it 'can return render urls' do
    expect(panel.render_url).to eq('/render/d-solo/IDBRfjSmz?panelId=11')
  end

  it "knows it's dashboard" do
    expect(panel.dashboard).to be_a(Dashboard)
  end
end
