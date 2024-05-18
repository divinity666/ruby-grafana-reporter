include Grafana

describe Grafana do
  context 'as admin' do
    subject { Grafana::Grafana.new(STUBS[:url], STUBS[:key_admin]) }

    it 'has Admin rights' do
      expect(subject.test_connection).to eq('Admin')
    end

    it 'raises error if datasource does not exist' do
      expect { subject.datasource_by_name(STUBS[:dashboard_does_not_exist]) }.to raise_error(DatasourceDoesNotExistError)
    end

    it 'raises error if dashboard does not exist' do
      expect { subject.dashboard(STUBS[:dashboard_does_not_exist]) }.to raise_error(DashboardDoesNotExistError)
    end

    it 'can identify datasource by model entry by name' do
      expect { subject.datasource_by_model_entry("demo") }.not_to raise_error
    end

    it 'can identify datasource by model entry by hash with uid' do
      expect { subject.datasource_by_model_entry({"uid": "000000001"}) }.not_to raise_error
    end

    it 'raises error if datasource by model entry contains unknown name' do
      expect { subject.datasource_by_model_entry("demobla") }.to raise_error(DatasourceDoesNotExistError)
    end

    it 'raises error if datasource by model entry contains unknown hash uid' do
      expect { subject.datasource_by_model_entry({"uid": "-1"}) }.to raise_error(DatasourceDoesNotExistError)
    end

    it 'raises error if datasource by id unknown uid' do
      expect { subject.datasource_by_uid("-1") }.to raise_error(DatasourceDoesNotExistError)
    end

    it 'shows error message if datasource_by_id is called and dashboard array contains nil object and removes it from dashboards' do
      subject.instance_variable_get(:@datasources)['test'] = nil
      expect(subject.instance_variable_get(:@datasources).length).to eq(7)
      expect(subject.logger).to receive(:warn).with(/is nil, which should never happen/)
      subject.datasource_by_id(STUBS[:datasource_sql])
      expect(subject.instance_variable_get(:@datasources).length).to eq(6)
    end

    it 'shows error message if datasource_by_uid is called and dashboard array contains nil object and removes it from dashboards' do
      subject.instance_variable_get(:@datasources)['test'] = nil
      expect(subject.instance_variable_get(:@datasources).length).to eq(7)
      expect(subject.logger).to receive(:warn).with(/is nil, which should never happen/)
      subject.datasource_by_uid('000000008')
      expect(subject.instance_variable_get(:@datasources).length).to eq(6)
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
