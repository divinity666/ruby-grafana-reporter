require 'webmock/rspec'

# run tests against mocked grafana instance
# WebMock.disable_net_connect!(:allow_localhost => true)

STUBS = {
  url: 'http://localhost',
  key_admin: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  key_viewer: 'viewerxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
  dashboard: 'IDBRfjSmz',
  panel_sql: { id: '11', letter: 'A', title: 'Temperaturen' },
  panel_graphite: { id: '12' },
  datasource_sql: '1',
  datasource_graphite: '2'
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

   stub_request(:get, 'http://localhost/api/frontend/settings').with(
      headers: default_header.merge({
        'Authorization' => /^Bearer (?:#{STUBS[:key_admin]}|#{STUBS[:key_viewer]})$/
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/frontend_settings.json'), headers: {})

    stub_request(:get, 'http://localhost/api/frontend/settings').with { |request|
      !request.headers.has_key?('Authorization') && request.headers.select { |k, v| k =~ /^(?:Accept|Accept-Encoding|Content-Type|User-Agent)$/ } == { 'Accept' => 'application/json', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' }
    }
    .to_return(status: 403, body: '{"message":"Permission denied"}', headers: {})

    stub_request(:get, 'http://localhost/api/datasources').with(
      headers: default_header
    )
    .to_return(status: 403, body: '{"message":"Permission denied"}', headers: {})

    stub_request(:get, 'http://localhost/api/datasources').with(
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: '[{"id":1,"orgId":1,"name":"demo","type":"mysql","typeLogoUrl":"public/app/plugins/datasource/mysql/img/mysql_logo.svg","access":"proxy","url":"localhost:3306","password":"demo","user":"demo","database":"demo","basicAuth":false,"isDefault":true,"jsonData":{},"readOnly":false}]', headers: {})

    stub_request(:get, "http://localhost/api/dashboards/uid/#{STUBS[:dashboard]}").with(
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/demo_dashboard.json'), headers: {})

    stub_request(:get, 'http://localhost/api/dashboards/home').with(
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
    .to_return(status: 200, body: '{"message":"Dashboard not found"}', headers: {})

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

    stub_request(:get, %r{http://localhost/render/d-solo/IDBRfjSmz\?from=\d+&fullscreen=true&panelId=11&theme=light&timeout=60(?:&var-[^&]+)*}).with(
      headers: default_header.merge({
        'Accept' => 'image/png',
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_image.png'), headers: {})

    stub_request(:post, 'http://localhost/api/tsdb/query').with(
      body: %r{.*SELECT   time as time_sec,   value / 10 as Ist FROM istwert_hk1 WHERE \$__unixEpochFilter\(time\) ORDER BY time DESC.*},
      headers: default_header.merge({
        'Authorization' => "Bearer #{STUBS[:key_admin]}"
      })
    )
    .to_return(status: 200, body: File.read('./spec/tests/sample_sql_response.json'), headers: {})

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
  end
end
