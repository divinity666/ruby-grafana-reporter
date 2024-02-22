# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |_ruby_grafana_reporter| 'https://github.com/divinity666/ruby-grafana-reporter' }

if not (ENV['APPVEYOR'] and ENV['APPVEYOR_BUILD_WORKER_IMAGE'] =~ /^Visual Studio.*/) # only for ocra building
  gemspec
else
  # exceptional handling for ocra builts
  File.open("ruby-grafana-reporter.gemspec",'r') do |file|
    # TODO properly read values and remove eval here
    file.each { |line| eval("gem #{$1}") if line =~ / *s.add(?:_runtime|_development)_dependency (.+)/ }
  end
end
gem 'rake', '~>13.0' if ENV['APPVEYOR'] or RUBY_PLATFORM =~ /cygwin|mswin|mingw|bccwin|wince|emx/ # only on windows
gem 'ocran', '~>1.3' if RUBY_PLATFORM =~ /cygwin|mswin|mingw|bccwin|wince|emx/ # only on windows
