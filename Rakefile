task :build do
  #update version file
  version = File.read("lib/VERSION.rb")
  File.write("lib/VERSION.rb", version.gsub(/GRAFANA_REPORTER_RELEASE_DATE *= [^$\n]*/, "GRAFANA_REPORTER_RELEASE_DATE = '#{Time.now.to_s[0..9]}'"))

  #build new versions
  require_relative 'lib/VERSION.rb'
  sh 'gem build'
  require_relative 'bin/get_single_file_application.rb'
  File.write("ruby-grafana-reporter-#{GRAFANA_REPORTER_VERSION.join(".")}.rb", get_result)
end

task :cleanup do
  rm Dir['*.gem'] << Dir['ruby-grafana-reporter-*.rb']
end

task :test do
  sh 'rspec spec/ruby-grafana-reporter_spec.rb'
end
