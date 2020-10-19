require_relative "./lib/VERSION.rb"

folders = [
  %w[],
  %w[grafana],
  %w[grafana_reporter logger],
  %w[grafana_reporter],
  %w[grafana_reporter asciidoctor extensions],
  %w[grafana_reporter asciidoctor],
  %w[grafana_reporter application]
]

Gem::Specification.new do |s|
  s.name        = 'ruby-grafana-reporter'
  s.version     = GRAFANA_REPORTER_VERSION.join(".")
  s.date        = GRAFANA_REPORTER_RELEASE_DATE
  s.summary     = "(Asciidoctor) Reporter Service for Grafana"
  s.description = "The reporter provides a full extension setup for the famous Asciidoctor and can perfectly integrate in a docker environment. It can be used as to convert single documents or run as a service.

As a result of the reporter, you receive PDF documents or any other format that is supported by Asciidoctor."
  s.authors     = ["Christian Kohlmeyer"]
  s.email       = 'kohly@gmx.de'
  s.files       = folders.collect { |folder| Dir[File.join(__dir__, "lib", *folder, '*.rb')].sort}.flatten << "LICENSE" << "README.md"
  s.homepage    = 'https://github.com/divinity666/ruby-grafana-reporter'
  s.license     = 'MIT'
end
