include Grafana

describe Panel do
  context 'old panel' do
    let(:panel) { Grafana::Grafana.new(STUBS[:url], STUBS[:key_admin]).dashboard(STUBS[:dashboard]).panel(STUBS[:panel_sql][:id]) }

    it 'contains proper field values' do
      expect(panel.field('title')).to eq('Temperaturen')
    end

    it 'can return queries properly' do
      expect(panel.query(STUBS[:panel_sql][:letter])).to be_a(String)
      expect { panel.query('Z') }.to raise_error(QueryLetterDoesNotExistError)
      expect { panel.query(nil) }.to raise_error(QueryLetterDoesNotExistError)
    end

    it 'can return render urls' do
      expect(panel.render_url).to eq('/render/d-solo/IDBRfjSmz?panelId=11')
    end

    it "knows it's dashboard" do
      expect(panel.dashboard).to be_a(Dashboard)
    end

    it 'retrieves default datasource, if not specified in panel' do
      expect(panel.datasource.name).to eq('demo')
    end
  end

  context 'empty panel stub' do
    subject { Panel.new({}, nil) }

    it 'can handle datasource nil values' do
      expect { subject.resolve_variable_datasource({'var-test' => Variable.new('test')}) }.not_to raise_error
    end
  end
end
