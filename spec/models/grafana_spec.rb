include Grafana

describe Grafana do
  context 'as admin' do
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

  context 'with https' do
    let(:logger) { a = Logger.new(STDOUT); a.level = Logger::WARN; a }
    subject { Grafana::Grafana.new('https://localhost', STUBS[:key_viewer], logger: logger) }

    it 'can use https' do
      expect(subject.test_connection).to eq('NON-Admin')
    end

    it 'can use custom ssl cert' do
      WebRequest.ssl_cert = 'spec/tests/cacert.pem'
      expect(logger).not_to receive(:warn)
      expect(subject.test_connection).to eq('NON-Admin')
    end

    it 'shows error, if ssl cert does not exist' do
      WebRequest.ssl_cert = 'does_not_exist_ssl'
      expect(logger).to receive(:warn).with(/SSL certificate file does not exist/).at_least(:once)
      expect(subject.test_connection).to eq('NON-Admin')
    end
  end

  context 'non-admin privileges' do
    subject { Grafana::Grafana.new(STUBS[:url], STUBS[:key_viewer]) }

    it 'has NON-Admin rights' do
      expect(subject.test_connection).to eq('NON-Admin')
    end

    it 'can return organization information' do
      expect(subject.organization['id']).to eq(STUBS[:org_id])
      expect(subject.organization['name']).to eq(STUBS[:org_name])
    end

    it 'can return grafana version' do
      expect(subject.version).to eq(STUBS[:version])
    end
  end
end
