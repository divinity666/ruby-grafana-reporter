if ENV['TRAVIS']
  require 'coveralls'
  Coveralls.wear! do
    add_filter "spec/"
  end
else
  require 'simplecov'
  SimpleCov.start do
    add_filter "spec/"
  end
end

require_relative '../lib/ruby_grafana_reporter'
require_relative 'ruby-grafana-reporter_spec.rb'
