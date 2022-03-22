include Grafana

describe PrometheusDatasource do
  subject { PrometheusDatasource.new({}) }

  it 'raises an error if an improper response format is given' do
    expect { subject.send(:preformat_response, "wrong format") }.to raise_error(UnsupportedQueryResponseReceivedError)
  end
end
