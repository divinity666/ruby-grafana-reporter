include GrafanaReporter

describe AbstractReport do
  subject { AbstractReport.new(Configuration.new) }

  it 'has abstract methods' do
    expect { subject.class.demo_report_classes }.to raise_error(NotImplementedError)
    expect { subject.build(nil, nil, nil) }.to raise_error(NotImplementedError)
  end
end
