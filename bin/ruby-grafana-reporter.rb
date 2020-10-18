require_relative '../lib/ruby-grafana-reporter'

GrafanaReporter::Application::Application.new.configure_and_run(ARGV)
