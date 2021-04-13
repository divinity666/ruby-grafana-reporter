include Grafana

describe AbstractQuery do
  subject { AbstractQuery.new(nil) }

  it 'has abstract methods' do
    expect { subject.pre_process }.to raise_error(NotImplementedError)
    expect { subject.post_process }.to raise_error(NotImplementedError)
  end
end
