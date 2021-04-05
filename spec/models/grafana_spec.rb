include Grafana

describe Grafana do
  context 'with datasources' do
    subject { Grafana::Grafana.new(STUBS[:url], STUBS[:key_admin]) }

    it 'has Admin rights' do
      expect(subject.test_connection).to eq('Admin')
    end

    it 'raises error if datasource does not exist' do
      expect { subject.datasource_by_name('blabla') }.to raise_error(DatasourceDoesNotExistError)
    end

    it 'raises error if dashboard does not exist' do
      expect { subject.dashboard('blabla') }.to raise_error(DashboardDoesNotExistError)
    end
  end

  context 'non-admin privileges' do
    subject { Grafana::Grafana.new(STUBS[:url], STUBS[:key_viewer]) }

    it 'has NON-Admin rights' do
      expect(subject.test_connection).to eq('NON-Admin')
    end
  end
end
