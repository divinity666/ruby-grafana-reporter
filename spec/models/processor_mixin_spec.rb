include GrafanaReporter::Asciidoctor

describe ProcessorMixin do
  subject { extend ProcessorMixin }

  it 'raises error for abstract method' do
    expect { subject.build_demo_entry(nil) }.to raise_error(NotImplementedError)
  end
end
