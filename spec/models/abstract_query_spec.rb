include Grafana

describe AbstractQuery do
  let(:query) { AbstractQuery.new }

  it 'has abstract methods' do
    expect { query.url }.to raise_error(NotImplementedError)
    expect { query.request }.to raise_error(NotImplementedError)
    expect { query.pre_process(nil) }.to raise_error(NotImplementedError)
    expect { query.post_process }.to raise_error(NotImplementedError)
    expect { AbstractQuery.build_demo_entry(nil) }.to raise_error(NotImplementedError)
  end
end
