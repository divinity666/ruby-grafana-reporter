include Grafana

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

    context 'date' do
      subject { dashboard.variables.select { |item| item.name == 'timestamp' }.first }

      it 'can format date' do
        expect(subject.value_formatted).to eq('1596660163000')
        expect(subject.value_formatted('date:seconds')).to eq('1596660163')
        expect(subject.value_formatted('date')).to eq('2020-08-05T20:42:43.000Z') # Time.at(1596660163).utc.iso8601(3)
        expect(subject.value_formatted('date:iso')).to eq('2020-08-05T20:42:43.000Z') # Time.at(1596660163).utc.iso8601(3)
        expect(subject.value_formatted('date:YYYY-MM-DD')).to eq('2020-08-05')
        expect(subject.value_formatted('date:M MM MMM MMMM D DD DDD DDDD d ddd dddd e E w ww W WW YY YYYY A a H HH h hh m mm s ss X')).to eq('8 08 Aug August 5 05 218 218 3 Wed Wednesday 3 3 31 31 32 32 20 2020 PM pm 22 22 10 10 42 42 43 43 1596660163')
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
      obj.raw_value = '$__all'
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
