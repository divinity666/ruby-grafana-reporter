include Grafana

describe InfluxDbDatasource do
  subject { InfluxDbDatasource.new(nil) }

  before do
    @panel_json = JSON.load(File.read('spec/tests/influx_db_composed_query.json'))
  end
  
  it 'can translate composed queries' do
    expect(subject.raw_query_from_panel_model(@panel_json['targets'].first)).to eq("SELECT non_negative_derivative(median(\"value\"), 10s) *1000000000 AS \"bla\", non_negative_derivative(mean(\"value\"), 10s) *1000000000 AS \"blubb\" FROM \"logins.count\" WHERE (\"datacenter\" = 'Africa') AND $timeFilter GROUP BY time($__interval), \"hostname\" fill(null)")
  end
end
