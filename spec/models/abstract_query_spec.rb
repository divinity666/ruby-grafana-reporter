include GrafanaReporter

describe AbstractQuery do
  subject { AbstractQuery.new(nil) }

  it 'has abstract methods' do
    expect { subject.pre_process }.to raise_error(NotImplementedError)
    expect { subject.post_process }.to raise_error(NotImplementedError)
  end

  it 'raises error, if a wrong grafana object is handed over' do
    expect { AbstractQuery.new(Grafana::Variable.new('test')) }.to raise_error(GrafanaReporterError)
  end

  it 'can log properly without given grafana object' do
    expect_any_instance_of(Logger).to receive(:warn).exactly(:once)
    subject.translate_date('now', nil, true)
  end

  context 'translate date' do
    it 'can translate now' do
      expect(subject.translate_date('now', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962683000')
      expect(subject.translate_date('now', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962682000')
    end

    it 'can translate now rounded seconds' do
      expect(subject.translate_date('now/s', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962683000')
      expect(subject.translate_date('now/s', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962683000')
      expect(subject.translate_date('now-s', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962682000')
      expect(subject.translate_date('now-s', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962681000')
      expect(subject.translate_date('now-s/s', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962682000')
      expect(subject.translate_date('now-s/s', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962682000')
    end

    it 'can translate now rounded minutes' do
      expect(subject.translate_date('now/m', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962680000')
      expect(subject.translate_date('now/m', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962739000')
      expect(subject.translate_date('now-m', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962623000')
      expect(subject.translate_date('now-m', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962622000')
      expect(subject.translate_date('now-m/m', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962620000')
      expect(subject.translate_date('now-m/m', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962679000')
    end

    it 'can translate now rounded hours' do
      expect(subject.translate_date('now/h', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595959200000')
      expect(subject.translate_date('now/h', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962799000')
      expect(subject.translate_date('now-h', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595959083000')
      expect(subject.translate_date('now-h', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595959082000')
      expect(subject.translate_date('now-h/h', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595955600000')
      expect(subject.translate_date('now-h/h', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595959199000')
    end

    it 'can translate now rounded days' do
      expect(subject.translate_date('now/d', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595887200000')
      expect(subject.translate_date('now/d', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595973599000')
      expect(subject.translate_date('now-d', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595876283000')
      expect(subject.translate_date('now-d', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595876282000')
      expect(subject.translate_date('now-d/d', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595800800000')
      expect(subject.translate_date('now-d/d', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595887199000')
      expect(subject.translate_date('now/d-d', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595800800000')
      expect(subject.translate_date('now/d-d', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595887199000')
    end

    it 'can translate now rounded weeks' do
      expect(subject.translate_date('now/w', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595800800000')
      expect(subject.translate_date('now/w', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1596405599000')
      expect(subject.translate_date('now-w', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595357883000')
      expect(subject.translate_date('now-w', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595357882000')
      expect(subject.translate_date('now-w/w', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595196000000')
      expect(subject.translate_date('now-w/w', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595800799000')
    end

    it 'can translate now rounded months' do
      expect(subject.translate_date('now/M', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1593554400000')
      expect(subject.translate_date('now/M', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1596232799000')
      expect(subject.translate_date('now-M', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1593370683000')
      expect(subject.translate_date('now-M', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1593370682000')
      expect(subject.translate_date('now-M/M', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1590962400000')
      expect(subject.translate_date('now-M/M', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1593554399000')
    end

    it 'can translate now rounded years' do
      expect(subject.translate_date('now/y', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1577829600000')
      expect(subject.translate_date('now/y', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1609451999000')
      expect(subject.translate_date('now-y', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1564340283000')
      expect(subject.translate_date('now-y', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1564340282000')
      expect(subject.translate_date('now-y/y', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1546293600000')
      expect(subject.translate_date('now-y/y', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1577829599000')
    end

    it 'can translate with specified timezone' do
      expect(subject.translate_date('now/y', Variable.new('2020-07-28T20:58:03.005+0200'), false, Variable.new('CET'))).to eq('1577833200000')
    end
  end
end
