include GrafanaReporter

describe AbstractTableFormatStrategy do
  subject { AbstractTableFormatStrategy.new }

  it 'has abstract class methods' do
    expect { subject.class.abbreviation }.to raise_error(NotImplementedError)
  end
end
