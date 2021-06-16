require 'webmock/rspec'

# run tests against mocked grafana instance
# WebMock.disable_net_connect!(:allow_localhost => true)

STUBS = {
  url: 'http://localhost',
  key_admin: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  key_viewer: 'viewerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  dashboard: 'IDBRfjSmz',
  panel_ds_unknown: { id: '10' },
  panel_sql: { id: '11', letter: 'A', title: 'Temperaturen' },
  panel_graphite: { id: '12', letter: 'A' },
  panel_prometheus: { id: '13', letter: 'A' },
  panel_influx: { id: '14', letter: 'A' },
  panel_broken_image: { id: '13' },
  datasource_sql: '1',
  datasource_graphite: '3',
  datasource_prometheus: '4',
  datasource_influx: '6'
}

default_header = {
  'Accept'=>'application/json',
  'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
  'Content-Type'=>'application/json',
  'User-Agent'=>'Ruby'
}

RSpec.configure do |config|
  config.before(:each) do
    stub_request(:get, "http://localhost/api/search").with(
      headers: default_header.merge({
        'Authorization' => /^Bearer (?:#{STUBS[:key_admin]}|#{STUBS[:key_viewer]})$/,
      })
    )
    .to_return(status: 200, body: "[{\"uid\":\"#{STUBS[:dashboard]}\"}]", headers: {})

    stub_request(:get, 'http://localhost/api/search').with { |request|
      !request.headers.has_key?('Authorization') && request.headers.select { |k, v| k =~ /^(?:Accept|Accept-Encoding|Content-Type|User-Agent)$/ } == { 'Accept' => 'application/json', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' }
    }
    .to_return(status: 403, body: '{"message":"Permission denied"}', headers: {})

   stub_request(:get, 'http://localhost/webhook').with(
      headers: {
        'User-Agent' => 'Ruby'
      }
    )
    .to_return(status: 200, body: "called test webhook", headers: {})

   stub_request(:get, %r{(?:http|https)://localhost/api/frontend/settings}).with(
      headers: default_header.merge({
        'Authorization' => /^Bearer (?:#{STUBS[:key_admin]}|#{STUBS[:key_viewer]})$/
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/frontend_settings.json'), headers: {})

    stub_request(:get, %r{(?:http|https)://localhost/api/frontend/settings}).with { |request|
      !request.headers.has_key?('Authorization') && request.headers.select { |k, v| k =~ /^(?:Accept|Accept-Encoding|Content-Type|User-Agent)$/ } == { 'Accept' => 'application/json', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' }
    }
    .to_return(status: 403, body: '{"message":"Permission denied"}', headers: {})

    stub_request(:get, %r{(?:http|https)://localhost/api/datasources}).with(
      headers: default_header
    )
    .to_return(status: 403, body: '{"message":"Permission denied"}', headers: {})

    stub_request(:get, %r{(?:http|https)://localhost/api/datasources$}).with(
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: '[{"id":1,"orgId":1,"name":"demo","type":"mysql","typeLogoUrl":"public/app/plugins/datasource/mysql/img/mysql_logo.svg","access":"proxy","url":"localhost:3306","password":"demo","user":"demo","database":"demo","basicAuth":false,"isDefault":true,"jsonData":{},"readOnly":false}]', headers: {})

    stub_request(:get, %r{(?:http|https)://localhost/api/dashboards/uid/#{STUBS[:dashboard]}}).with(
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/demo_dashboard.json'), headers: {})

    stub_request(:get, %r{(?:http|https)://localhost/api/dashboards/home}).with(
      headers: default_header.merge({
        'Authorization' => /Bearer (?:#{STUBS[:key_admin]}|#{STUBS[:key_viewer]})/
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/demo_dashboard.json'), headers: {})

    stub_request(:get, 'http://localhost/api/dashboards/home').with { |request|
      !request.headers.has_key?('Authorization') && request.headers.select { |k, v| k =~ /^(?:Accept|Accept-Encoding|Content-Type|User-Agent)$/ } == { 'Accept' => 'application/json', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' }
    }
    .to_return(status: 403, body: '{"message":"Permission denied"}', headers: {})

    stub_request(:get, 'http://localhost/api/dashboards/uid/blabla').with(
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 404, body: '{"message":"Dashboard not found"}', headers: {})

    stub_request(:post, 'http://localhost/api/tsdb/query').with(
      body: /.*SELECT 1[^\d]*/,
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: '{"results":{"A":{"refId":"A","meta":{"rowCount":1,"sql":"SELECT 1"},"series":null,"tables":[{"columns":[{"text":"1"}],"rows":[[1]]}],"dataframes":null}}}', headers: {})

    stub_request(:post, 'http://localhost/api/tsdb/query').with(
      body: /.*SELECT 1 as value WHERE value = 0*/,
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: '{"results":{"A":{"refId":"A","meta":{"rowCount":0,"sql":"SELECT 1 as value WHERE value = 0"},"series":null,"tables":null,"dataframes":null}}}', headers: {})

    stub_request(:get, %r{http://localhost/render/d-solo/IDBRfjSmz\?from=\d+&fullscreen=true&panelId=(?:10|11)&theme=light&timeout=60(?:&var-[^&]+)*}).with(
      headers: default_header.merge({
        'Accept' => 'image/png',
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_image.png', File.size('./spec/tests/sample_image.png')), headers: {})

    stub_request(:post, 'http://localhost/api/tsdb/query').with(
      body: %r{.*SELECT   time as time_sec,   value / 10 as Ist FROM istwert_hk1 WHERE \$__unixEpochFilter\(time\) ORDER BY time DESC.*},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_sql_response.json'), headers: {})

    stub_request(:get, %r{http://localhost/render/d-solo/IDBRfjSmz\?from=\d+&fullscreen=true&panelId=13&theme=light&timeout=60(?:&var-[^&]+)*}).with(
      headers: default_header.merge({
        'Accept' => 'image/png',
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 500, body: File.read('./spec/tests/broken_image_response.html'), headers: {})

    stub_request(:get, %r{http://localhost/api/annotations(?:\?.*)?}).with(
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_annotations_response.json'), headers: {})

    stub_request(:get, %r{http://localhost/api/alerts(?:\?.*)?}).with(
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_alerts_response.json'), headers: {})

    # Graphite
    stub_request(:post, 'http://localhost/api/datasources/proxy/3/render').with(
      body: {"format"=>"json", "from"=>"00:00_19700101", "target"=>"alias(movingAverage(scaleToSeconds(apps.fakesite.web_server_01.counters.request_status.code_302.count, 10), 20), 'cpu')", "until"=>"00:00_19700101"},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}",
        'Content-Type' => 'application/x-www-form-urlencoded'
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_graphite_response.json'), headers: {})

    stub_request(:post, 'http://localhost/api/datasources/proxy/3/render').with(
      body: {"format"=>"json", "from"=>"00:00_19700101", "target"=>"alias(movingAverage(scaleToSeconds(apps.fakesite.backend_01.counters.request_status.code_302.count, 10), 20), 'cpu')", "until"=>"00:00_19700101"},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}",
        'Content-Type' => 'application/x-www-form-urlencoded'
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_graphite_single_response.json'), headers: {})

    # Prometheus
    stub_request(:get, 'http://localhost/api/datasources/proxy/4/api/v1/query_range').with(
      query: {"query": "sum by(mode)(irate(node_cpu_seconds_total{job=\"node\", instance=~\"$node:.*\", mode!=\"idle\"}[5m])) > 0", 'start': 0, 'end': 0},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_prometheus_response.json'), headers: {})

    stub_request(:get, 'http://localhost/api/datasources/proxy/4/api/v1/query_range').with(
      query: {"query": "sum by(mode)(irate(node_cpu_seconds_total{job=\"node\", instance=~\"$node:.*\", mode=\"iowait\"}[5m])) > 0", 'start': 0, 'end': 0},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_prometheus_single_response.json'), headers: {})

    # Influx
    stub_request(:get, 'http://localhost/api/datasources/proxy/6/query?db=site&q=SELECT%20non_negative_derivative(mean(%22value%22)%2C%2010s)%20*1000000000%20FROM%20%22logins.count%22%20WHERE%20time%20%3E%3D%20now()%20-%201h%20GROUP%20BY%20time(10s)%2C%20%22hostname%22%20fill(null)&epoch=ms').with(
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_influx_response.json'), headers: {})

    stub_request(:get, 'http://localhost/api/datasources/proxy/6/query?db=site&q=SELECT%20non_negative_derivative(mean(%22value%22),%2010s)%20*1000000000%20FROM%20%22logins.count%22%20WHERE%20time%20%3E=%20now()%20-%201h%20AND%20%22hostname%22%20=%20%2210.1.0.100.1%22%20GROUP%20BY%20time(10s)%20fill(null)&epoch=ms').with(
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_influx_single_response.json'), headers: {})
  end
end
