# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) {|ruby_grafana_reporter| "https://github.com/divinity666/ruby-grafana-reporter" }

ruby '~>2'
gem "asciidoctor", '~>2'
gem "asciidoctor-pdf", '~>1'
gem "zip", '~>2'

group :test, optional: true do
  gem 'rake'
  gem 'coveralls', require: false
  gem 'rspec', '~>3.9'
  gem 'webmock', '~>3.9'
end
