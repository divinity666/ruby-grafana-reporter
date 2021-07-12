include Grafana

describe SqlDatasource do
  subject { SqlDatasource.new(nil) }

  it 'can replace variables' do
    expect(subject.send :replace_variables, '$my_var', { 'var-my_var' => Variable.new('ok') }).to eq('ok')
    expect(subject.send :replace_variables, '${my_var}', { 'var-my_var' => Variable.new('ok') }).to eq('ok')
  end

  it 'does not replace variables if names only partly match' do
    expect(subject.send :replace_variables, '$my_var_test', { 'var-my_var' => Variable.new('not-ok') }).to eq('$my_var_test')
  end

  it 'will only replace variables with accepted grafana naming scheme' do
    expect(subject.send :replace_variables, '$my-var', { 'var-my-var' => Variable.new('not-ok') }).to eq('$my-var')
  end
end
