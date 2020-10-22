require 'coveralls'
Coveralls.wear!

require_relative '../lib/ruby-grafana-reporter.rb'
require 'webmock/rspec'

include Grafana
include GrafanaReporter
include GrafanaReporter::Application
include GrafanaReporter::Asciidoctor
include GrafanaReporter::Asciidoctor::Extensions

describe Dashboard do
  let(:dashboard) { Dashboard.new(JSON.parse(File.read('./spec/tests/demo_dashboard.json'))['dashboard'], Grafana::Grafana.new('')) }

  it 'contains panels' do
    expect(dashboard.panels.length).to eq(6)
    expect(dashboard.panel(11)).to be_a(Panel)
    expect(dashboard.panel(11).field('id')).to eq(11)
    expect(dashboard.panel(11).field('no_field_exists')).to eq('')
    expect { dashboard.panel(99) }.to raise_error(PanelDoesNotExistError)
  end

  it 'contains variables' do
    expect(dashboard.variables.length).to eq(4)
    expect(dashboard.variables.select { |item| item.name == 'test' }.first.name).to eq('test')
    variable = dashboard.variables.select { |item| item.name == 'test' }.first

    expect(dashboard.from_time).to eq('now-24h')
    expect(dashboard.to_time).to be_nil
  end
end

describe Panel do
  let(:panel) { Dashboard.new(JSON.parse(File.read('./spec/tests/demo_dashboard.json'))['dashboard'], Grafana::Grafana.new('')).panel(11) }

  it 'contains proper field values' do
    expect(panel.field('title')).to eq('Temperaturen')
  end

  it 'can return queries properly' do
    expect(panel.query('D')).to be_a(String)
    expect { panel.query('Z') }.to raise_error(QueryLetterDoesNotExistError)
    expect { panel.query(nil) }.to raise_error(QueryLetterDoesNotExistError)
  end

  it 'can return render urls' do
    expect(panel.render_url).to eq('/render/d-solo/IDBRfjSmz?panelId=11')
  end

  it "knows it's dashboard" do
    expect(panel.dashboard).to be_a(Dashboard)
  end
end

describe Variable do
  context 'formatting of simple string values' do
    let(:dashboard) { Dashboard.new(JSON.parse(File.read('./spec/tests/demo_dashboard.json'))['dashboard'], Grafana::Grafana.new('')) }
    subject { dashboard.variables.select { |item| item.name == 'testsingle' }.first }

    it 'returns proper raw value for strings' do
      expect(subject.raw_value).to eq("test bla12$/\"'.a,|=\\")
    end

    it 'is no multi' do
      expect(subject.multi?).to be false
    end

    it 'formats values properly' do
      # Conversions of grafana
      # Variable value	 test bla12$/"'.a\,|=\

      # Test: 		 test bla12$/"''.a,|=\
      # Test quoted: 	'test bla12$/"''.a,|=\'
      # Test alt: 	 test bla12$/"''.a,|=\

      # json: 		"test bla12$/\"'.a,|=\\"
      # csv: 		 test bla12$/"'.a,|=\
      # glob: 		 test bla12$/"'.a,|=\
      # bla: 		 test bla12$/"'.a,|=\
      # distributed: 	 test bla12$/"'.a,|=\
      # doublequote: 	"test bla12$/\"'.a,|=\"
      # singlequote: 	'test bla12$/"\'.a,|=\'
      # lucene: 	 test\ bla12$\/\"'.a,\|\=\\
      # percentencode:  test%20bla12%24%2F%22%27.a%2C%7C%3D%5C
      # pipe: 		 test bla12$/"'.a,|=\
      # raw: 		 test bla12$/"'.a,|=\
      # regex: 	 test bla12\$\/"'\.a,\|=\\
      # sqlstring: 	'test bla12$/"''.a,|=\'

      content = "test bla12$/\"'.a,|=\\"

      expect(subject.value_formatted).to eq('test bla12$/"\'\'.a,|=\\')
      expect(subject.value_formatted('csv')).to eq(content)
      expect(subject.value_formatted('distributed')).to 	eq(content)
      expect(subject.value_formatted('doublequote')).to 	eq("\"test bla12$/\\\"'.a,|=\\\"")
      expect(subject.value_formatted('json')).to eq('"test bla12$/\"\'.a,|=\\"')
      expect(subject.value_formatted('lucene')).to eq('test\ bla12$\/\"\'.a,\|\=\\\\')
      expect(subject.value_formatted('percentencode')).to eq('test%20bla12%24%2F%22%27.a%2C%7C%3D%5C')
      expect(subject.value_formatted('pipe')).to eq(content)
      expect(subject.value_formatted('raw')).to eq(content)
      expect(subject.value_formatted('regex')).to eq('test bla12\$\/"\'\.a,\|=\\\\')
      expect(subject.value_formatted('singlequote')).to eq("'test bla12$/\"\\'.a,|=\\'")
      expect(subject.value_formatted('sqlstring')).to eq('\'test bla12$/"\'\'.a,|=\\\'')
      expect(subject.value_formatted('glob')).to eq(content)
      expect(subject.value_formatted('other')).to eq(content)
    end

    it 'sets text when changing raw_value' do
      subject.raw_value = '1'
      expect(subject.raw_value).to eq('1')
      expect(subject.text).to eq('resolved')
    end

    context "date" do
      subject {dashboard.variables.select{|item| item.name == "timestamp"}.first}


      it "can format date" do
        expect(subject.value_formatted).to eq("1596660163000")
        expect(subject.value_formatted('date:seconds')).to eq("1596660163")
        expect(subject.value_formatted('date')).to eq("2020-08-05T20:42:43.000Z") #Time.at(1596660163).utc.iso8601(3)
        expect(subject.value_formatted('date:iso')).to eq("2020-08-05T20:42:43.000Z") #Time.at(1596660163).utc.iso8601(3)
        expect(subject.value_formatted('date:YYYY-MM-DD')).to eq("2020-08-05")
	#excluded tests with H HH h hh, because of time zones
	#22 22 10 10 was expected
        expect(subject.value_formatted('date:M MM MMM MMMM D DD d ddd dddd e E w ww W WW YY YYYY A a m mm s ss X')).to eq("8 08 Aug August 5 05 3 Wed Wednesday 3 3 31 31 32 32 20 2020 PM pm 42 42 43 43 1596660163")
      end
    end
  end

  context 'formatting for array values' do
    subject { Dashboard.new(JSON.parse(File.read('./spec/tests/demo_dashboard.json'))['dashboard'], Grafana::Grafana.new('')).variables.select { |item| item.name == 'testmulti' }.first }

    it 'returns proper raw value for arrays' do
      expect(subject.raw_value).to match_array(['1', '2', ',', '$', '/', '"', "'", '.', 'a', '|', '\\'])
    end

    it 'is multi' do
      expect(subject.multi?).to be true
    end

    it 'formats value default' do
      # Conversions of grafana
      # Variable value	 1,2,\,,$,/,",',.,a,|,\

      # Test:		 '1','2',',','$','/','"','''','.','a','|','\'
      # Test quoted:	''1','2',',','$','/','"','''','.','a','|','\''
      # Test alt:	 '1','2',',','$','/','"','''','.','a','|','\'

      # json: 		["1","2",",","$","/","\"","'",".","a","|","\\"]
      # csv: 		 1,2,,,$,/,",',.,a,|,\
      # glob: 		{1,2,,,$,/,",',.,a,|,\}
      # bla: 		{1,2,,,$,/,",',.,a,|,\}
      # distributed: 	 1,Test2=2,Test2=,,Test2=$,Test2=/,Test2=",Test2=',Test2=.,Test2=a,Test2=|,Test2=\
      # doublequote: 	"1","2",",","$","/","\"","'",".","a","|","\"
      # singlequote: 	'1','2',',','$','/','"','\'','.','a','|','\'
      # lucene: 	("1" OR "2" OR "," OR "$" OR "\/" OR "\"" OR "'" OR "." OR "a" OR "\|" OR "\\")
      # percentencode: %7B1%2C2%2C%2C%2C%24%2C%2F%2C%22%2C%27%2C.%2Ca%2C%7C%2C%5C%7D
      # pipe: 		 1|2|,|$|/|"|'|.|a|||\
      # raw: 		{1,2,,,$,/,",',.,a,|,\}
      # regex: 	(1|2|,|\$|\/|"|'|\.|a|\||\\)
      # sqlstring: 	'1','2',',','$','/','"','''','.','a','|','\'
      expect(subject.value_formatted).to eq("'1','2',',','$','/','\"','''','.','a','|','\\'")
      expect(subject.value_formatted).to eq("'1','2',',','$','/','\"','''','.','a','|','\\'")
      expect(subject.value_formatted('csv')).to eq('1,2,,,$,/,",\',.,a,|,\\')
      expect(subject.value_formatted('distributed')).to 	eq("1,testmulti=2,testmulti=,,testmulti=$,testmulti=/,testmulti=\",testmulti=',testmulti=.,testmulti=a,testmulti=|,testmulti=\\")
      expect(subject.value_formatted('doublequote')).to 	eq('"1","2",",","$","/","\"","\'",".","a","|","\\"')
      expect(subject.value_formatted('json')).to eq('["1","2",",","$","/","\"","\'",".","a","|","\\\\"]')
      expect(subject.value_formatted('lucene')).to eq('("1" OR "2" OR "," OR "$" OR "\/" OR "\"" OR "\'" OR "." OR "a" OR "\|" OR "\\\\")') # NOTE also escapes = with \
      expect(subject.value_formatted('percentencode')).to eq('%7B1%2C2%2C%2C%2C%24%2C%2F%2C%22%2C%27%2C.%2Ca%2C%7C%2C%5C%7D')
      expect(subject.value_formatted('pipe')).to eq("1|2|,|$|/|\"|'|.|a|||\\")
      expect(subject.value_formatted('raw')).to eq("{1,2,,,$,/,\",',.,a,|,\\}")
      expect(subject.value_formatted('regex')).to eq('(1|2|,|\$|\/|"|\'|\.|a|\||\\\\)')
      expect(subject.value_formatted('singlequote')).to eq("'1','2',',','$','/','\"','\\'','.','a','|','\\'")
      expect(subject.value_formatted('sqlstring')).to eq("'1','2',',','$','/','\"','''','.','a','|','\\'")
      expect(subject.value_formatted('glob')).to eq("{1,2,,,$,/,\",',.,a,|,\\}")
      expect(subject.value_formatted('other')).to eq("{1,2,,,$,/,\",',.,a,|,\\}")
    end

    it "handles selection 'All' properly" do
      obj = Dashboard.new(JSON.parse(File.read('./spec/tests/demo_dashboard.json'))['dashboard'], Grafana::Grafana.new('')).variables.select { |item| item.name == 'testmulti' }.first
      obj.raw_value = 'All'
      expect(obj.value_formatted).to eq("'1','2',',','$','/','\"','''','.','a','|','\\'")
    end
  end

  context 'formatting for grafana config values' do
    subject { Dashboard.new(JSON.parse(File.read('./spec/tests/demo_dashboard.json'))['dashboard'], Grafana::Grafana.new('')).variables.select { |item| item.name == 'test' }.first }

    it 'contains proper values' do
      expect(subject.multi?).to be_falsey
      expect(subject.raw_value).to eq('10')
    end

    it 'contains name' do
      expect(subject.name).to eq('test')
    end
  end
end

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
      expect(subject.translate_date('now', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962683000')
    end

    it 'can translate now rounded seconds' do
      expect(subject.translate_date('now/s', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962683000')
      expect(subject.translate_date('now/s', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962684000')
      expect(subject.translate_date('now-s', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962682000')
      expect(subject.translate_date('now-s', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962682000')
      expect(subject.translate_date('now-s/s', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962682000')
      expect(subject.translate_date('now-s/s', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962683000')
    end

    it 'can translate now rounded minutes' do
      expect(subject.translate_date('now/m', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962680000')
      expect(subject.translate_date('now/m', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962740000')
      expect(subject.translate_date('now-m', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962623000')
      expect(subject.translate_date('now-m', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962623000')
      expect(subject.translate_date('now-m/m', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595962620000')
      expect(subject.translate_date('now-m/m', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962680000')
    end

    it 'can translate now rounded hours' do
      expect(subject.translate_date('now/h', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595959200000')
      expect(subject.translate_date('now/h', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595962800000')
      expect(subject.translate_date('now-h', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595959083000')
      expect(subject.translate_date('now-h', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595959083000')
      expect(subject.translate_date('now-h/h', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595955600000')
      expect(subject.translate_date('now-h/h', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595959200000')
    end

    it 'can translate now rounded days' do
      expect(subject.translate_date('now/d', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595887200000')
      expect(subject.translate_date('now/d', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595973600000')
      expect(subject.translate_date('now-d', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595876283000')
      expect(subject.translate_date('now-d', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595876283000')
      expect(subject.translate_date('now-d/d', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595800800000')
      expect(subject.translate_date('now-d/d', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595887200000')
    end

    it 'can translate now rounded weeks' do
      expect(subject.translate_date('now/w', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595800800000')
      expect(subject.translate_date('now/w', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1596405600000')
      expect(subject.translate_date('now-w', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595357883000')
      expect(subject.translate_date('now-w', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595357883000')
      expect(subject.translate_date('now-w/w', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1595196000000')
      expect(subject.translate_date('now-w/w', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1595800800000')
    end

    it 'can translate now rounded months' do
      expect(subject.translate_date('now/M', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1593554400000')
      expect(subject.translate_date('now/M', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1596232800000')
      expect(subject.translate_date('now-M', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1593370683000')
      expect(subject.translate_date('now-M', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1593370683000')
      expect(subject.translate_date('now-M/M', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1590962400000')
      expect(subject.translate_date('now-M/M', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1593554400000')
    end

    it 'can translate now rounded years' do
      expect(subject.translate_date('now/y', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1577829600000')
      expect(subject.translate_date('now/y', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1609452000000')
      expect(subject.translate_date('now-y', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1564340283000')
      expect(subject.translate_date('now-y', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1564340283000')
      expect(subject.translate_date('now-y/y', Variable.new('2020-07-28T20:58:03.005+0200'), false)).to eq('1546293600000')
      expect(subject.translate_date('now-y/y', Variable.new('2020-07-28T20:58:03.005+0200'), true)).to eq('1577829600000')
    end
  end
end

describe SqlFirstValueQuery do
  context 'after processing' do
    subject do
      obj = SqlFirstValueQuery.new('SELECT 1', 1)
      obj.result = Marshal.load("\x04\bo:\x10Net::HTTPOK\x0F:\x12@http_versionI\"\b1.1\x06:\x06ET:\n@codeI\"\b200\x06;\aT:\r@messageI\"\aOK\x06;\aT:\f@header{\rI\"\x12cache-control\x06;\aT[\x06I\"\rno-cache\x06;\aTI\"\x11content-type\x06;\aT[\x06I\"\x15application/json\x06;\aTI\"\fexpires\x06;\aT[\x06I\"\a-1\x06;\aTI\"\vpragma\x06;\aT[\x06I\"\rno-cache\x06;\aTI\"\x14x-frame-options\x06;\aT[\x06I\"\tdeny\x06;\aTI\"\tdate\x06;\aT[\x06I\"\"Sun, 12 Jul 2020 12:02:57 GMT\x06;\aTI\"\x13content-length\x06;\aT[\x06I\"\b153\x06;\aTI\"\x0Fconnection\x06;\aT[\x06I\"\nclose\x06;\aT:\n@bodyI\"\x01\x99{\"results\":{\"A\":{\"refId\":\"A\",\"meta\":{\"rowCount\":1,\"sql\":\"SELECT 1\"},\"series\":null,\"tables\":[{\"columns\":[{\"text\":\"1\"}],\"rows\":[[1]]}],\"dataframes\":null}}}\x06;\aT:\n@readT:\t@uri0:\x14@decode_contentT:\f@socket0:\x10@body_existT")
      obj.post_process
      obj
    end

    it 'calculates proper result' do
      expect(subject.result).to eq(1)
    end
  end
end

describe Configuration do
  context 'with config file' do
    subject do
      obj = Configuration.new
      obj.load_config(YAML.load_file('./spec/tests/demo_config.txt'))
      obj
    end

    it 'is in mode service' do
      expect(subject.mode).to eq(Configuration::MODE_SERVICE)
    end

    it 'reads port' do
      expect(subject.webserver_port).to eq(8050)
    end

    it 'has no template' do
      expect(subject.template).to be_nil
    end

    it 'returns grafana instances' do
      expect(subject.grafana_instances.length).to eq(1)
      expect(subject.grafana_instances[0]).to eq('default')
    end

    it 'returns grafana host' do
      expect(subject.grafana_host).to eq('http://localhost')
    end

    it 'returns reports folder with trailing slash' do
      expect(subject.reports_folder).to eq('./')
    end

    it 'returns templates folder with trailing slash' do
      expect(subject.templates_folder).to eq('./')
    end

    it 'returns images folder' do
      expect(subject.images_folder).to eq('./')
    end

    it 'can read datasources' do
      expect(subject.grafana_datasources).to eq({ 'demo' => 1, 'bla' => 2 })
    end

    it 'is valid' do
      expect { subject.validate }.not_to raise_error
    end
  end

  context 'without config file' do
    subject { Configuration.new }

    it 'is in mode service' do
      expect(subject.mode).to eq(Configuration::MODE_SERVICE)
    end

    it 'has default port' do
      expect(subject.webserver_port).to eq(8815)
    end

    it 'has no template' do
      expect(subject.template).to be_nil
    end

    it 'returns images folder' do
      expect(subject.images_folder).to eq('./')
    end

    it 'is invalid' do
      expect { subject.validate }.to raise_error(ConfigurationDoesNotMatchSchemaError)
    end
  end

  context 'validator' do
    subject { Configuration.new }

    it 'validates required fields' do
      subject.load_config({
                            'grafana' => { 'default' => { 'host' => 'test' } }
                          })
      expect { subject.validate }.not_to raise_error
    end

    it 'validates optional datasources' do
      subject.load_config({
                            'grafana' => { 'default' => { 'host' => 'test', 'datasources' => { 'test' => 1 } } }
                          })
      expect { subject.validate }.not_to raise_error
    end

    it 'raises error if item exists without required subitem' do
      subject.load_config({
                            'grafana' => { 'default' => { 'host' => 'test', 'datasources' => {} } }
                          })
      expect { subject.validate }.to raise_error(ConfigurationDoesNotMatchSchemaError)
    end

    it 'raises error on wrong datasource type' do
      subject.load_config({
                            'grafana' => { 'default' => { 'host' => 'test', 'datasources' => { 'test' => 'bla' } } }
                          })
      expect { subject.validate }.to raise_error(ConfigurationDoesNotMatchSchemaError)
    end

    it 'raises error if folder does not exist' do
      subject.load_config({
                            'grafana' => { 'default' => { 'host' => 'test' } },
                            'grafana-reporter' => { 'reports-folder' => 'ewfhenwf8' }
                          })
      expect { subject.validate }.to raise_error(FolderDoesNotExistError)
    end

    it 'warns if not evaluated configurations exist' do
      subject.load_config({
                            'grafana' => { 'default' => { 'host' => 'test' } },
                            'grafana-reporter' => { 'repots-folder' => 'ewfhenwf8' }
                          })
      expect(subject.logger).to receive(:warn).with("Item 'repots-folder' in configuration is unknown to the reporter and will be ignored")
      subject.validate
    end
  end

  context 'command line interface' do
    subject { Configuration.new }

    it 'returns help' do
      expect { subject.configure_by_command_line(['--help']) }.to output(/--debug/).to_stdout
      expect { subject.configure_by_command_line }.to output(/--debug/).to_stdout
    end

    it 'can handle wrong config files' do
      expect { subject.configure_by_command_line(['./spec/tests/demo_report.adoc']) }.to raise_error(ConfigurationError)
    end

    it 'can handle correct config files' do
      expect { subject.configure_by_command_line(['./spec/tests/demo_config.txt', '--test', 'default']) }.not_to raise_error
    end
  end
end

describe Report do
  subject do
    config = Configuration.new
    config.load_config(YAML.load_file('./spec/tests/demo_config.txt'))

    Report.new(config, './spec/tests/demo_report.adoc')
  end

  it 'can preconfigure grafana instance' do
    expect(subject.grafana('default').datasource_id('demo')).to eq(1)
    expect(subject.grafana('default').datasource_id('bla')).to eq(2)
  end
end

# run tests against mocked grafana instance
# WebMock.disable_net_connect!(:allow_localhost => true)

stub_url = 'http://localhost'
stub_key = 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
stub_dashboard = 'IDBRfjSmz'
stub_panel = '11'
stub_panel_query = 'A'
stub_panel_title = 'Temperaturen'
stub_datasource = '1'

RSpec.configure do |config|
  config.before(:each) do
    stub_request(:get, 'http://localhost/api/datasources').with(
      headers: {
        'Accept' => 'application/json',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Content-Type' => 'application/json',
        'User-Agent' => 'Ruby'
      }
    )
                                                          .to_return(status: 403, body: '{"message":"Permission denied"}', headers: {})

    stub_request(:get, 'http://localhost/api/datasources').with(
      headers: {
        'Accept' => 'application/json',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization' => 'Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'Content-Type' => 'application/json',
        'User-Agent' => 'Ruby'
      }
    )
                                                          .to_return(status: 200, body: '[{"id":1,"orgId":1,"name":"demo","type":"mysql","typeLogoUrl":"public/app/plugins/datasource/mysql/img/mysql_logo.svg","access":"proxy","url":"localhost:3306","password":"demo","user":"demo","database":"demo","basicAuth":false,"isDefault":true,"jsonData":{},"readOnly":false}]', headers: {})

    stub_request(:get, "http://localhost/api/dashboards/uid/#{stub_dashboard}").with(
      headers: {
        'Accept' => 'application/json',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization' => 'Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'Content-Type' => 'application/json',
        'User-Agent' => 'Ruby'
      }
    )
                                                                               .to_return(status: 200, body: File.read('./spec/tests/demo_dashboard.json'), headers: {})

    stub_request(:get, 'http://localhost/api/dashboards/home').with(
      headers: {
        'Accept' => 'application/json',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Content-Type' => 'application/json',
        'User-Agent' => 'Ruby'
      }
    )
                                                              .to_return(status: 200, body: File.read('./spec/tests/demo_dashboard.json'), headers: {})

    stub_request(:get, 'http://localhost/api/dashboards/uid/blabla').with(
      headers: {
        'Accept' => 'application/json',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization' => 'Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'Content-Type' => 'application/json',
        'User-Agent' => 'Ruby'
      }
    )
                                                                    .to_return(status: 200, body: '{"message":"Dashboard not found"}', headers: {})

    stub_request(:post, 'http://localhost/api/tsdb/query').with(
      body: /.*SELECT 1.*/,
      headers: {
        'Accept' => 'application/json',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization' => 'Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'Content-Type' => 'application/json',
        'User-Agent' => 'Ruby'
      }
    )
                                                          .to_return(status: 200, body: '{"results":{"A":{"refId":"A","meta":{"rowCount":1,"sql":"SELECT 1"},"series":null,"tables":[{"columns":[{"text":"1"}],"rows":[[1]]}],"dataframes":null}}}', headers: {})

    stub_request(:get, %r{http://localhost/render/d-solo/IDBRfjSmz\?from=\d+&fullscreen=true&panelId=11&theme=light&timeout=60(?:&var-[^&]+)*}).with(
      headers: {
        'Accept' => 'image/png',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization' => 'Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'Content-Type' => 'application/json',
        'User-Agent' => 'Ruby'
      }
    )
                                                                                                                                               .to_return(status: 200, body: File.read('./spec/tests/sample_image.png'), headers: {})

    stub_request(:post, 'http://localhost/api/tsdb/query').with(
      body: %r{.*SELECT   time as time_sec,   value / 10 as Ist FROM istwert_hk1 WHERE \$__unixEpochFilter\(time\) ORDER BY time DESC.*},
      headers: {
        'Accept' => 'application/json',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization' => 'Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'Content-Type' => 'application/json',
        'User-Agent' => 'Ruby'
      }
    )
                                                          .to_return(status: 200, body: File.read('./spec/tests/sample_sql_response.json'), headers: {})

    stub_request(:get, %r{http://localhost/api/annotations(?:\?.*)?}).with(
      headers: {
        'Accept' => 'application/json',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization' => 'Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'Content-Type' => 'application/json',
        'User-Agent' => 'Ruby'
      }
    )
                                                                     .to_return(status: 200, body: File.read('./spec/tests/sample_annotations_response.json'), headers: {})

    stub_request(:get, %r{http://localhost/api/alerts(?:\?.*)?}).with(
      headers: {
        'Accept' => 'application/json',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization' => 'Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'Content-Type' => 'application/json',
        'User-Agent' => 'Ruby'
      }
    )
                                                                .to_return(status: 200, body: File.read('./spec/tests/sample_alerts_response.json'), headers: {})
  end
end

describe Application do
  context 'with config file' do
    subject do
      config = Configuration.new
      yaml = "grafana-reporter:
  port: 8050
  templates-folder: ./spec/tests
  reports-folder: .

grafana:
  default:
    host: http://localhost
    api_key: #{stub_key}

default-document-attributes:
  imagesdir: images/"

      config.load_config(YAML.load(yaml))
      app = GrafanaReporter::Application::Application.new
      app.config = config
      app
    end

    it 'can handle invalid web requests' do
      expect { subject.send(:handle_request, 'GET /rend HTTP/1.1') }.to raise_error(WebserviceUnknownPathError)
      expect { subject.send(:handle_request, 'GET /render HTTP/1.1') }.to raise_error(MissingTemplateError)
      expect { subject.send(:handle_request, 'GET /render?var-template=does_not_exist HTTP/1.1') }.to raise_error(MissingTemplateError)
    end

    it 'can handle all web requests' do
      result = subject.send(:handle_request, 'GET /render?var-template=demo_report HTTP/1.1')
      expect(result).to include("Found\r\nLocation: /view_report?report_id=")

      id = result.split("\r\n")[1].gsub(/.*report_id=([^\r\n]*).*/, '\1')
      expect(subject.send(:handle_request, "GET /view_report?report_id=#{id} HTTP/1.1")).to include('in progress')
      expect { subject.send(:handle_request, "GET /cancel_report?report_id=#{id} HTTP/1.1") }.not_to raise_error
      expect { subject.send(:handle_request, "GET /view_log?report_id=#{id} HTTP/1.1") }.not_to raise_error
      expect(subject.send(:handle_request, 'GET /overview HTTP/1.1')).to include(id)

      sleep 1 # race condition with webmock here, because report might not be finished earlier
      expect(subject.send(:handle_request, "GET /view_report?report_id=#{id} HTTP/1.1")).to include('application/pdf')
    end
  end

  context 'command line' do
    subject { GrafanaReporter::Application::Application.new }

    it 'can configure and run' do
      expect { subject.configure_and_run(['./spec/tests/demo_config.txt', '--test', 'default', '-d', 'FATAL']) }.to output("Admin\n").to_stdout
    end
  end
end

describe Grafana do
  context 'with datasources' do
    subject { Grafana::Grafana.new(stub_url, stub_key) }

    it 'connects properly' do
      expect(subject.test_connection).to eq('Admin')
    end
  end

  context 'without datasources' do
    subject { Grafana::Grafana.new(stub_url, stub_key, datasources: {}) }

    it 'raises error if datasource does not exist' do
      expect { subject.datasource_id('blabla') }.to raise_error(DatasourceDoesNotExistError)
    end

    it 'raises error if dashboard does not exist' do
      expect { subject.dashboard('blabla') }.to raise_error(DashboardDoesNotExistError)
    end
  end

  context 'non-admin privileges' do
    subject { Grafana::Grafana.new(stub_url) }

    it 'has only NON-Admin rights' do
      expect(subject.test_connection).to eq('NON-Admin')
    end
  end
end

describe PanelQueryValueInlineMacro do
  before do
    config = Configuration.new
    config.load_config({ 'grafana' => { 'default' => { 'host' => stub_url, 'api_key' => stub_key } } })
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      inline_macro PanelQueryValueInlineMacro.new.current_report(report)
    end
  end

  it 'can be processed' do
    expect(Asciidoctor.convert("grafana_panel_query_value:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert("grafana_panel_query_value:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).to include('<p>1594308060000')
  end

  it 'can replace values' do
    expect(Asciidoctor.convert("grafana_panel_query_value:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",replace_values_1=\"1594308060000:geht\"]", to_file: false)).to include('<p>geht')
    expect(Asciidoctor.convert("grafana_panel_query_value:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",replace_values_2=\"1594308060000:geht\"]", to_file: false)).to include('<p>1594308060000')
  end

  it 'raises error on malformed replace_values' do
    expect(Asciidoctor.convert("grafana_panel_query_value:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",replace_values_1=\"" + '159430\:8060000\::ge\:ht' + '"]', to_file: false)).not_to include('The specified replace_values statement')
    expect(Asciidoctor.convert("grafana_panel_query_value:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",replace_values_1=\"" + '159430\:8060000\:\:ge\:ht' + '"]', to_file: false)).to include('The specified replace_values statement')
    expect(Asciidoctor.convert("grafana_panel_query_value:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",replace_values_1=\"" + '159430:8060000:\:ge\:ht' + '"]', to_file: false)).to include('The specified replace_values statement')
  end

  it 'can filter columns' do
    expect(Asciidoctor.convert("grafana_panel_query_value:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",filter_columns=\"time_sec\"]", to_file: false)).to include('<p>43.9')
    expect(Asciidoctor.convert("grafana_panel_query_value:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",filter_columns=\"Warmwasser\"]", to_file: false)).to include('<p>1594308060000')
  end

  it 'can filter columns and format values' do
    expect(Asciidoctor.convert("grafana_panel_query_value:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",format=\",%.2f\",filter_columns=\"time_sec\"]", to_file: false)).to include('<p>43.90')
  end
end

describe PanelImageBlockMacro do
  before do
    config = Configuration.new
    config.load_config({ 'grafana' => { 'default' => { 'host' => stub_url, 'api_key' => stub_key } } })
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      block_macro PanelImageBlockMacro.new.current_report(report)
    end
  end

  it 'can be processed' do
    expect(Asciidoctor.convert("grafana_panel_image::#{stub_panel}[dashboard=\"#{stub_dashboard}\"]", to_file: false)).to include('<img src="gf_image_').and match (/(?!Error)/)
  end
end

describe PanelImageInlineMacro do
  before do
    config = Configuration.new
    config.load_config({ 'grafana' => { 'default' => { 'host' => stub_url, 'api_key' => stub_key } } })
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      inline_macro PanelImageInlineMacro.new.current_report(report)
    end
  end

  it 'retrieves images properly' do
    expect(Asciidoctor.convert("grafana_panel_image:#{stub_panel}[dashboard=\"#{stub_dashboard}\"]", to_file: false)).to include('<img src="gf_image_').and match(/(?!Error)/)
  end

  it 'cleans up created temporary files' do
    ts = Time.now.to_s
    result = Asciidoctor.convert("grafana_panel_image:#{stub_panel}[dashboard=\"#{stub_dashboard}\"]", to_file: false, attributes: { 'grafana-report-timestamp' => ts })
    tmp_file = result.to_s.gsub(/.*img src="([^"]+)".*/m, '\1')
    expect(File.exist?("./spec/templates/images/#{tmp_file}")).to be false
  end
end

describe SqlTableIncludeProcessor do
  before do
    config = Configuration.new
    config.load_config({ 'grafana' => { 'default' => { 'host' => stub_url, 'api_key' => stub_key } } })
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      include_processor SqlTableIncludeProcessor.new.current_report(report)
    end
  end

  it 'can be processed' do
    expect(Asciidoctor.convert("include::grafana_sql_table:#{stub_datasource}[sql=\"SELECT 1\"]", to_file: false)).not_to include('GrafanaReporterError')
  end
end

describe SqlValueInlineMacro do
  before do
    config = Configuration.new
    config.load_config({ 'grafana' => { 'default' => { 'host' => stub_url, 'api_key' => stub_key } } })
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      inline_macro SqlValueInlineMacro.new.current_report(report)
    end
  end

  it 'can be processed' do
    expect(Asciidoctor.convert("grafana_sql_value:#{stub_datasource}[sql=\"SELECT 1\"]", to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert("grafana_sql_value:#{stub_datasource}[sql=\"SELECT 1\"]", to_file: false)).to include('1')
  end

  it 'returns error message if no sql statement specified' do
    expect(Asciidoctor.convert("grafana_sql_value:#{stub_datasource}[test=\"bla\"]", to_file: false)).to include('MissingSqlQueryError')
    expect(Asciidoctor.convert("grafana_sql_value:#{stub_datasource}[]", to_file: false)).to include('MissingSqlQueryError')
  end

  it 'returns error message if invalid datasource id is specified' do
    expect(Asciidoctor.convert('grafana_sql_value:99[sql="SELECT 1"]', to_file: false)).to include('GrafanaError: Datasource')
  end

  it 'replaces grafana variables in sql query' do
    expect(Asciidoctor.convert("grafana_sql_value:#{stub_datasource}[sql=\"SELECT $my-var\"]", to_file: false, attributes: { 'var-my-var' => 1 })).to include('1')
  end
end

describe PanelPropertyInlineMacro do
  before do
    config = Configuration.new
    config.load_config({ 'grafana' => { 'default' => { 'host' => stub_url, 'api_key' => stub_key } } })
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      inline_macro PanelPropertyInlineMacro.new.current_report(report)
    end
  end

  it 'can be processed' do
    expect(Asciidoctor.convert("grafana_panel_property:#{stub_panel}[\"title\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).not_to include('GrafanaError')
    expect(Asciidoctor.convert("grafana_panel_property:#{stub_panel}[\"title\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).to include(stub_panel_title)
  end

  it 'replaces grafana variables in result' do
    expect(Asciidoctor.convert("grafana_panel_property:#{stub_panel}[\"description\",dashboard=\"#{stub_dashboard}\"]", to_file: false, attributes: { 'var-my-var' => 'Meine Ersetzung' })).to include('Meine Ersetzung')
  end
end

describe PanelQueryTableIncludeProcessor do
  before do
    config = Configuration.new
    config.load_config({ 'grafana' => { 'default' => { 'host' => stub_url, 'api_key' => stub_key } } })
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      include_processor PanelQueryTableIncludeProcessor.new.current_report(report)
    end
  end

  it 'can return full results' do
    expect(Asciidoctor.convert("include::grafana_panel_query_table:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert("include::grafana_panel_query_table:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).to match(/<p>\| 1594308060000 \| 43.9/)
  end

  it 'can replace values' do
    expect(Asciidoctor.convert("include::grafana_panel_query_table:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",replace_values_1=\"1594308060000:geht\"]", to_file: false)).to match(/<p>\| geht \| 43.9/)
    expect(Asciidoctor.convert("include::grafana_panel_query_table:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",replace_values_2=\"1594308060000:geht\"]", to_file: false)).to match(/<p>\| 1594308060000 \| 43.9/)
  end

  it 'can replace regex values' do
    expect(Asciidoctor.convert("include::grafana_panel_query_table:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",format=\",%.2f\",filter_columns=\"time_sec\",replace_values_2=\"^(43)\..*$:geht - \\1\"]", to_file: false)).to include('| geht - 43').and include('| 44.00')
  end

  it 'can replace values with value comparison' do
    expect(Asciidoctor.convert("include::grafana_panel_query_table:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",format=\",%.2f\",filter_columns=\"time_sec\",replace_values_2=\"<44:geht\"]", to_file: false)).to include('| geht').and include('| 44.00')
    expect(Asciidoctor.convert("include::grafana_panel_query_table:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",format=\",%.2f\",filter_columns=\"time_sec\",replace_values_2=\"<44:\\1 zu klein\"]", to_file: false)).to include('| 43.90 zu klein').and include('| 44.00')
  end

  it 'can filter columns' do
    expect(Asciidoctor.convert("include::grafana_panel_query_table:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",filter_columns=\"time_sec\"]", to_file: false)).to match(/<p>\| 43.9/)
    expect(Asciidoctor.convert("include::grafana_panel_query_table:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",filter_columns=\"Warmwasser\"]", to_file: false)).to match(/<p>\| 1594308060000\n/)
  end

  it 'can format values' do
    expect(Asciidoctor.convert("include::grafana_panel_query_table:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",format=\",%.2f\"]", to_file: false)).to match(/<p>\| 1594308060000 \| 43.90/)
  end
  
  it 'handles column and row divider' do
    expect(Asciidoctor.convert("include::grafana_panel_query_table:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",column_divider=\" col \",row_divider=\"row \"]", to_file: false)).to match(/<p>row 1594308060000 col 43.9/)
  end
  
  it 'can transpose results' do
    expect(Asciidoctor.convert("include::grafana_panel_query_table:#{stub_panel}[query=\"#{stub_panel_query}\",dashboard=\"#{stub_dashboard}\",transpose=\"true\"]", to_file: false)).to match(/<p>\| 1594308060000 \| 1594308030000 \|/)
  end
end

describe AnnotationsTableIncludeProcessor do
  before do
    config = Configuration.new
    config.load_config({ 'grafana' => { 'default' => { 'host' => stub_url, 'api_key' => stub_key } } })
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      include_processor AnnotationsTableIncludeProcessor.new.current_report(report)
    end
  end

  it 'can be processed' do
    expect(Asciidoctor.convert("include::grafana_annotations[columns=\"time,id,alertName\",panel=\"#{stub_panel}\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert("include::grafana_annotations[columns=\"time,id,alertName\",panel=\"#{stub_panel}\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).to include('Panel Title alert')
  end

  it 'shows error if unknown columns are specified' do
    expect(Asciidoctor.convert("include::grafana_annotations[columns=\"time,id,alert_name\",panel=\"#{stub_panel}\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).to include('key')
  end

  it 'shows error if columns attribute is missing' do
    expect(Asciidoctor.convert("include::grafana_annotations[panel=\"#{stub_panel}\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).to include("Missing mandatory attribute 'columns'.")
  end

  it 'shows error if time range is unknown' do
    expect(Asciidoctor.convert("include::grafana_annotations[columns=\"time,id,alert_name\",panel=\"#{stub_panel}\",dashboard=\"#{stub_dashboard}\",from=\"unknown\"]", to_file: false)).to include('The specified time range')
  end
end

describe AlertsTableIncludeProcessor do
  before do
    config = Configuration.new
    config.load_config({ 'grafana' => { 'default' => { 'host' => stub_url, 'api_key' => stub_key } } })
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      include_processor AlertsTableIncludeProcessor.new.current_report(report)
    end
  end

  it 'can be processed' do
    expect(Asciidoctor.convert("include::grafana_alerts[columns=\"newStateDate,name,state\",panel=\"#{stub_panel}\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert("include::grafana_alerts[columns=\"newStateDate,name,state\",panel=\"#{stub_panel}\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).to include('Panel Title alert')
  end

  it 'shows error if unknown columns are specified' do
    expect(Asciidoctor.convert("include::grafana_alerts[columns=\"newStateDate,name,stated\",panel=\"#{stub_panel}\",dashboard=\"#{stub_dashboard}\"]", to_file: false)).to include('key')
  end
end

describe ShowEnvironmentIncludeProcessor do
  before do
    config = Configuration.new
    config.load_config({ 'grafana' => { 'default' => { 'host' => stub_url, 'api_key' => stub_key } } })
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      include_processor ShowEnvironmentIncludeProcessor.new.current_report(report)
    end
  end

  it 'can be processed' do
    expect(Asciidoctor.convert('include::grafana_environment[]', to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert('include::grafana_environment[]', to_file: false)).to include('doctype-article')
  end
end

describe ShowHelpIncludeProcessor do
  before do
    config = Configuration.new
    config.load_config({ 'grafana' => { 'default' => { 'host' => stub_url, 'api_key' => stub_key } } })
    report = Report.new(config, './spec/tests/demo_report.adoc')
    Asciidoctor::Extensions.unregister_all
    Asciidoctor::Extensions.register do
      include_processor ShowHelpIncludeProcessor.new.current_report(report)
    end
  end

  it 'can be processed' do
    expect(Asciidoctor.convert('include::grafana_help[]', to_file: false)).not_to include('GrafanaReporterError')
    expect(Asciidoctor.convert('include::grafana_help[]', to_file: false)).to include('grafana_panel_image')
  end
end
