include GrafanaReporter

describe DemoReportWizard do
  let(:grafana) { Grafana::Grafana.new(STUBS[:url], STUBS[:key_admin]) }
  subject { DemoReportWizard.new([Configuration]) }

  it 'raises error, if class does not implement required method' do
    allow(STDOUT).to receive(:puts)
    allow(STDOUT).to receive(:print)
    allow(STDOUT).to receive(:write)

    expect(subject.build(grafana)).to include("Method 'build_demo_entry' not implemented")
  end
end
