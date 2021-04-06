include Grafana

describe AbstractDatasource do
  subject { AbstractDatasource.new }

  it 'has abstract methods' do
    expect { subject.name }.to raise_error(NotImplementedError)
    expect { subject.category }.to raise_error(NotImplementedError)
    expect { subject.model }.to raise_error(NotImplementedError)
    expect { subject.url(nil) }.to raise_error(NotImplementedError)
    expect { subject.request(nil) }.to raise_error(NotImplementedError)
    expect { subject.preformat_response(nil) }.to raise_error(NotImplementedError)
  end

  it 'raises error if invalid datasource query is provided' do
    expect { AbstractDatasource.build_instance(nil) }.to raise_error(InvalidDatasourceQueryProvidedError)
  end

  it 'raises error if unknown datasource definition is provided' do
    expect { AbstractDatasource.build_instance({'meta' => {'category' => 'unknown', 'id' => 'unknown_ds'}}) }.to raise_error(DatasourceTypeNotSupportedError)
  end
end
