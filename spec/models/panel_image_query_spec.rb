include Grafana

describe PanelImageQuery do
  subject { PanelImageQuery.new(Dashboard.new(JSON.parse(File.read('./spec/tests/demo_dashboard.json'))['dashboard'], Grafana::Grafana.new('')).panel(11)) }

  it 'can build uri without parameters' do
    subject.pre_process(nil)
    expect(subject.url).to match(%r{/render/d-solo/IDBRfjSmz\?panelId=11(?:&var-[^&]+)*&fullscreen=true&theme=light&timeout=60})
  end

  it 'can build uri with parameters' do
    subject.merge_variables(height: Variable.new(200), width: Variable.new(500))
    subject.pre_process(nil)
    expect(subject.url).to match(%r{/render/d-solo/IDBRfjSmz\?panelId=11(?:&var-[^&]+)*&height=200&width=500&fullscreen=true&theme=light&timeout=60&from=\d+&to=\d+})
  end

  it 'can merge existing variable and keep all meta data' do
    expect(subject.variables['var-test'].text).to eq('ten')
    subject.merge_variables("var-test": Variable.new(1))
    expect(subject.variables['var-test'].raw_value).to eq('1')
    expect(subject.variables['var-test'].text).to eq('one')
  end

  it 'can build request' do
    subject.pre_process(nil)
    expect(subject.request).to eq(accept: 'image/png')
  end

  it 'can rename render- variables' do
    subject.merge_variables("render-height": Variable.new(200), "render-width": Variable.new(500))
    subject.pre_process(nil)
    expect(subject.url).to match(%r{/render/d-solo/IDBRfjSmz\?panelId=11(?:&var-[^&]+)*&height=200&width=500&fullscreen=true&theme=light&timeout=60})
  end

  it 'filters out non-url parameters' do
    subject.merge_variables("test-height": Variable.new(200), "render-width": Variable.new(500))
    subject.pre_process(nil)
    expect(subject.url).to match(%r{/render/d-solo/IDBRfjSmz\?panelId=11(?:&var-[^&]+)*&width=500&fullscreen=true&theme=light&timeout=60})
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
