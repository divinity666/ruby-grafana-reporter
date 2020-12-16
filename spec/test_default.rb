if ENV['TRAVIS']
  require 'coveralls'
  Coveralls.wear!
else
  require 'simplecov'
  SimpleCov.start
end

require_relative '../lib/ruby-grafana-reporter'
require_relative 'ruby-grafana-reporter_spec'
