task :default => [:test]

task :check_asciidoctor_docker do
  # fetch asciidoctor versions from docker file
  require 'net/http'
  uri = URI('https://raw.githubusercontent.com/asciidoctor/docker-asciidoctor/master/Dockerfile')
  html = Net::HTTP.get(uri)
  cur_asciidoctor_version = html.scan(/ARG asciidoctor_version=([\d\.\w]+)/).flatten.first
  cur_asciidoctor_pdf_version = html.scan(/ARG asciidoctor_pdf_version=([\d\.\w]+)/).flatten.first
  cur_asciidoctor_epub3_version = html.scan(/ARG asciidoctor_epub3_version=([\d\.\w]+)/).flatten.first

  # read asciidoctor versions from gemspec
  gemspec = File.read('ruby-grafana-reporter.gemspec')
  expected_asciidoctor_version = gemspec.scan(/add_runtime_dependency 'asciidoctor', '~>([\d\.\w]+)'/).flatten.first
  expected_asciidoctor_pdf_version = gemspec.scan(/add_runtime_dependency 'asciidoctor-pdf', '~>([\d\.\w]+)'/).flatten.first
  expected_asciidoctor_epub3_version = gemspec.scan(/add_runtime_dependency 'asciidoctor-epub3', '~>([\d\.\w]+)'/).flatten.first

  if cur_asciidoctor_version.start_with?(expected_asciidoctor_version) and cur_asciidoctor_pdf_version.start_with?(expected_asciidoctor_pdf_version) and cur_asciidoctor_epub3_version.start_with?(expected_asciidoctor_epub3_version)
    puts "Versions are OK"
  else
    puts "Version dependencies in gemspec have to be adapted to docker versions:"
    puts " - asciidoctor: #{cur_asciidoctor_version}"
    puts " - asciidoctor-pdf: #{cur_asciidoctor_pdf_version}"
    puts " - asciidoctor-epub3: #{cur_asciidoctor_epub3_version}"
    exit 1
  end
end

task :build do
  Rake::Task["check_asciidoctor_docker"].invoke

  #update version file
  version = File.read("lib/VERSION.rb")
  File.write("lib/VERSION.rb", version.gsub(/GRAFANA_REPORTER_RELEASE_DATE *= [^$\n]*/, "GRAFANA_REPORTER_RELEASE_DATE = '#{Time.now.to_s[0..9]}'"))

  #build new versions
  require_relative 'lib/VERSION.rb'
  sh 'gem build ruby-grafana-reporter.gemspec'
  require_relative 'bin/get_single_file_application.rb'
  File.write("ruby-grafana-reporter-#{GRAFANA_REPORTER_VERSION.join(".")}.rb", get_result)

  # run single file application to see it is running without issues
  ruby "ruby-grafana-reporter-#{GRAFANA_REPORTER_VERSION.join(".")}.rb"
end

task :cleanup do
  rm Dir['*.gem'] << Dir['ruby-grafana-reporter-*.rb']
end

task :test do
  Rake::Task["check_asciidoctor_docker"].invoke
  sh 'bundle exec rspec spec/ruby-grafana-reporter_spec.rb'
end
