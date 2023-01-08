require 'webmock/rspec'

# run tests against mocked grafana instance
# WebMock.disable_net_connect!(:allow_localhost => true)

STUBS = {
  url: 'http://localhost',
  key_admin: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  key_viewer: 'viewerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  org_id: 1,
  org_name: 'Main',
  version: '6.5.3',
  dashboard: 'IDBRfjSmz',
  dashboard_does_not_exist: 'blabla',
  panel_ds_unknown: { id: '15' },
  panel_sql: { id: '11', letter: 'A', title: 'Temperaturen' },
  panel_graphite: { id: '12', letter: 'A' },
  panel_prometheus: { id: '13', letter: 'A' },
  panel_prometheus_new_format: { id: '17', letter: 'A' },
  panel_prometheus_new_format_variable_datasource: { id: '18', letter: 'A' },
  panel_influx: { id: '14', letter: 'A' },
  panel_broken_image: { id: '13' },
  panel_does_not_exist: { id: '99'},
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
    stub_request(:get, "https://github.com/divinity666/ruby-grafana-reporter/releases/latest")
    .to_return(status: 302, body: "relocated", headers: {'location' => "https://github.com/divinity666/ruby-grafana-reporter/releases/tag/v#{GRAFANA_REPORTER_VERSION.join('.')}"})

    stub_request(:get, "http://localhost/api/org/").with(
      headers: default_header.merge({
        'Authorization' => /^Bearer (?:#{STUBS[:key_admin]}|#{STUBS[:key_viewer]})$/,
      })
    )
    .to_return(status: 200, body: "{\"id\":#{STUBS[:org_id]},\"name\":\"#{STUBS[:org_name]}\"}", headers: {})

    stub_request(:get, %r{(?:http|https)://localhost/api/health})
    .to_return(status: 200, body: "{\"commit\":\"05025c5\",\"database\":\"ok\",\"version\":\"#{STUBS[:version]}\"}", headers: {})

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

    stub_request(:get, %r{(?:http|https)://localhost/api/datasources$}).with(
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
        'Authorization' => /Bearer (?:#{STUBS[:key_admin]}|#{STUBS[:key_viewer]})/
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
      body: /.*SELECT error.*/,
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: '{"results":{"A":{"refId":"A","error":"db query error: query failed - please inspect Grafana server log for details"}}}', headers: {})

    stub_request(:post, 'http://localhost/api/tsdb/query').with(
      body: /.*SELECT 1[^\d]*/,
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: '{"results":{"A":{"refId":"A","meta":{"rowCount":1,"sql":"SELECT 1"},"series":null,"tables":[{"columns":[{"text":"1"}],"rows":[[1]]}],"dataframes":null}}}', headers: {})

    stub_request(:post, 'http://localhost/api/ds/query').with(
      body: /.*SELECT 1[^\d]*/,
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: ' {"results":{"A":{"frames":[{"schema":{"refId":"A","meta":{"executedQueryString":"SELECT 1"},"fields":[{"name":"1","type":"number","typeInfo":{"frame":"int64","nullable":true}}]},"data":{"values":[[1]]}}],"refId":"A"}}}', headers: {})

    stub_request(:post, 'http://localhost/api/tsdb/query').with(
      body: /.*SELECT 2[^\d]*/,
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: '{"results":{"A":{"refId":"A","meta":{"rowCount":2,"sql":"SELECT 2 UNION ALL SELECT 3"},"series":null,"tables":[{"columns":[{"text":"1"}],"rows":[[2],[3]],"type":"table","refId":"A","meta":{"rowCount":2,"sql":"SELECT 1 UNION ALL SELECT 2"}}],"dataframes":null}}}', headers: {})

    stub_request(:post, 'http://localhost/api/tsdb/query').with(
      body: /.*SELECT 1 as value WHERE value = 0*/,
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: '{"results":{"A":{"refId":"A","meta":{"rowCount":0,"sql":"SELECT 1 as value WHERE value = 0"},"series":null,"tables":null,"dataframes":null}}}', headers: {})

    stub_request(:get, %r{http://localhost/render/d-solo/IDBRfjSmz\?from=\d+&fullscreen=true&panelId=(?:15|11)&theme=light&timeout=60(?:&var-[^&]+)*}).with(
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
    .to_return(status: 500, body: File.read('./spec/tests/broken_image_response.txt'), headers: {})

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
      query: {"query": "node_memory_Buffers_bytes{job=\"node\", instance=~\"$node:.*\"}", 'start': 0, 'end': 0, 'step':10},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_prometheus_response_dataframes.json'), headers: {})

    stub_request(:post, "http://localhost/api/ds/query").
       with(
         body: "{\"from\":\"0\",\"to\":\"0\",\"queries\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"000000008\"},\"datasourceId\":4,\"exemplar\":false,\"expr\":\"sum by(mode)(irate(node_cpu_seconds_total{job=\\\"node\\\", instance=~\\\"$node:.*\\\", mode!=\\\"idle\\\"}[5m])) > 0\",\"format\":\"time_series\",\"interval\":\"\",\"metric\":\"\",\"queryType\":\"timeSeriesQuery\",\"refId\":\"A\",\"step\":10}],\"range\":{\"raw\":{\"from\":\"0\",\"to\":\"0\"}}}",
         headers: {
           'Accept'=>'application/json',
           'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
           'Authorization'=>'Bearer xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
           'Content-Type'=>'application/json',
           'User-Agent'=>'Ruby'
       }
     )
     .to_return(status: 200, body: File.read('./spec/tests/sample_prometheus_response.json'), headers: {})

    stub_request(:get, 'http://localhost/api/datasources/proxy/4/api/v1/query_range').with(
      query: {"query": "sum by(mode)(irate(node_cpu_seconds_total{job=\"node\", instance=~\"$node:.*\", mode!=\"idle\"}[5m])) > 0", 'start': 0, 'end': 0, 'step':10},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_prometheus_response.json'), headers: {})

    stub_request(:get, 'http://localhost/api/datasources/proxy/4/api/v1/query_range').with(
      query: {"query": "sum by(mode)(irate(node_cpu_seconds_total{job=\"node\", instance=~\"$node:.*\", mode=\"iowait\"}[5m])) > 0", 'start': 0, 'end': 0, 'step':15},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_prometheus_single_response.json'), headers: {})

    stub_request(:get, 'http://localhost/api/datasources/proxy/4/api/v1/query_range').with(
      query: {"query": "ille gal", 'start': 0, 'end': 0, 'step': 15},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: '{"status":"error","errorType":"bad_data","error":"1:6: parse error: unexpected identifier \"gal\""}', headers: {})

    stub_request(:get, 'http://localhost/api/datasources/proxy/4/api/v1/query').with(
      query: {"query": "prometheus_build_info{}",'time': 1},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: '{ "status": "success", "data": { "resultType": "vector", "result": [ { "metric": { "__name__": "prometheus_build_info", "branch": "HEAD", "goversion": "go1.16.4", "instance": "demo.robustperception.io:9090", "job": "prometheus", "revision": "db7f0bcec27bd8aeebad6b08ac849516efa9ae02", "version": "2.27.1" }, "value": [ 1639345182, "15" ] } ] } }', headers: {})

    stub_request(:get, 'http://localhost/api/datasources/proxy/4/api/v1/query').with(
      query: {"query": "\"test\"",'time': 0},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: '{ "status": "success", "data": { "resultType": "string", "result": [1639345182,"test"] } }', headers: {})

    stub_request(:get, 'http://localhost/api/datasources/proxy/4/api/v1/query').with(
      query: {"query": "1+11",'time': 0},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: '{ "status": "success", "data": { "resultType": "scalar", "result": [1639345182, 12] } }', headers: {})

    # Influx
    stub_request(:get, 'http://localhost/api/datasources/proxy/6/query?db=site&q=SELECT%20non_negative_derivative%28mean%28%22value%22%29%2C%2010s%29%20%2A1000000000%20FROM%20%22logins.count%22%20WHERE%20time%20%3E%3D%200ms%20and%20time%20%3C%3D%200ms%20GROUP%20BY%20time%280s%29%2C%20%22hostname%22%20fill%28null%29&epoch=ms').with(
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_influx_response.json'), headers: {})

    stub_request(:get, 'http://localhost/api/datasources/proxy/6/query').with(
      query: {
        'db' => 'site',
        'epoch' => 'ms',
        'q' => 'SELECT non_negative_derivative(mean("value"), 10s) *1000000000 FROM "logins.count" WHERE time >= 0ms AND "hostname" = "10.1.0.100.1" GROUP BY time(35999) fill(null)'
      },
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_influx_single_response.json'), headers: {})

    stub_request(:get, 'http://localhost/api/datasources/proxy/6/query').with(
      query: {
        'db' => 'site',
        'epoch' => 'ms',
        'q' => 'SELECT non_negative_derivative(mean("value"), 10s) *1000000000 FROM "logins.count" WHERE time >= 0ms AND "hostname" = "10.1.0.100.1" GROUP BY time(1m) fill(null)'
      },
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_influx_single_response.json'), headers: {})

    stub_request(:get, 'http://localhost/api/datasources/proxy/6/query').with(
      query: {
        'db' => 'site',
        'epoch' => 'ms',
        'q' => 'SELECT non_negative_derivative(mean("value"), 10s) *1000000000 FROM "logins.count" WHERE time >= 0ms AND "hostname" = "10.1.0.100.1" GROUP BY time(35s) fill(null)'
      },
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_influx_single_response.json'), headers: {})

    stub_request(:get, 'http://localhost/api/datasources/proxy/6/query').with(
      query: {
        'db' => 'site',
        'epoch' => 'ms',
        'q' => 'SELECT non_negative_derivative(mean("value"), 10s) *1000000000 FROM "logins.count" WHERE time >= 0ms AND "hostname" = "10.1.0.100.1" GROUP BY time(10s) fill(null)'
      },
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_influx_single_response.json'), headers: {})
  end
end
