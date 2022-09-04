# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |_ruby_grafana_reporter| 'https://github.com/divinity666/ruby-grafana-reporter' }

gemspec
gem 'rake', '~>13.0' if ENV['APPVEYOR']
gem 'ocra', '~>1.3' if ENV['APPVEYOR'] and ENV['APPVEYOR_BUILD_WORKER_IMAGE'] =~ /^Visual Studio.*/
