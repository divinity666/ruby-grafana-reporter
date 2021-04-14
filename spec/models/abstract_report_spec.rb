include GrafanaReporter

describe AbstractReport do
  subject { AbstractReport.new(Configuration.new, './spec/tests/demo_report.adoc') }

  it 'has abstract methods' do
    expect { subject.progress }.to raise_error(NotImplementedError)
  end
end
