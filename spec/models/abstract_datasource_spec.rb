include Grafana

describe AbstractDatasource do
  subject { AbstractDatasource.new(nil) }

  it 'has abstract methods' do
    expect { subject.url(nil) }.to raise_error(NotImplementedError)
    expect { subject.request(nil) }.to raise_error(NotImplementedError)
    expect { subject.preformat_response(nil) }.to raise_error(NotImplementedError)
    expect { subject.raw_query(nil) }.to raise_error(NotImplementedError)
  end

  it 'raises error if invalid datasource query is provided' do
    expect { AbstractDatasource.build_instance(nil) }.to raise_error(InvalidDatasourceQueryProvidedError)
  end

  it 'raises error if unknown datasource definition is provided' do
    expect { AbstractDatasource.build_instance({'meta' => {'category' => 'unknown', 'id' => 'unknown_ds'}}) }.to raise_error(DatasourceTypeNotSupportedError)
  end
end
