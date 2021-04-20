include Grafana

describe AbstractDatasource do
  subject { AbstractDatasource.new(nil) }

  it 'has abstract methods' do
    expect { subject.request(nil) }.to raise_error(NotImplementedError)
    expect { subject.raw_query_from_panel_model(nil) }.to raise_error(NotImplementedError)
  end

  it 'raises error if invalid datasource query is provided' do
    expect { AbstractDatasource.build_instance(nil) }.to raise_error(InvalidDatasourceQueryProvidedError)
  end

  it 'returns unsupported datasource if not supported' do
    expect(AbstractDatasource.build_instance({'meta' => {'category' => 'unknown', 'id' => 'unknown_ds'}})).to be_a(Grafana::UnsupportedDatasource)
  end
end
