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
  s.summary     = "Reporter Service for Grafana"
  s.description = <<~DONE
    The reporter provides reporting capabilities for Grafana. It is based on
    (but not limited to) asciidoctor report templates, which can dynamically
    integrate Grafana panels, queries, images etc. to create dynamic PDF
    reports on the fly. The report may also be returned in any other format
    that asciidoctor supports.

    The reporter can run standalone or as a webservice. It is built to
    integrate without further dependencies with the asciidoctor docker image.
  DONE
  s.author      = "Christian Kohlmeyer"
  s.email       = 'kohly@gmx.de'
  s.files       = folders.collect { |folder| Dir[File.join(__dir__, "lib", *folder, '*.rb')].sort}.flatten << "LICENSE" << "README.md"
  s.homepage    = 'https://github.com/divinity666/ruby-grafana-reporter'
  s.license     = 'MIT'

  s.metadata = {
    "source_code_uri" => "https://github.com/divinity666/ruby-grafana-reporter",
    "bug_tracker_uri" => "https://github.com/divinity666/ruby-grafana-reporter/issues"
  }
  s.post_install_message = 'You may want to start your journey with "GrafanaReporter::Application::Application.new.configure_and_run".'

  s.required_ruby_version = '~>2.5.5'
  s.extra_rdoc_files = ['README.md','LICENSE']

  s.requirements << 'asciidoctor, ~>2.0.10'
  s.requirements << 'asciidoctor-pdf, ~>1.5.3'
  s.requirements << 'zip, ~>2.0.2'

  s.bindir = 'bin'

  s.add_runtime_dependency 'asciidoctor', '~>2.0.10'
  s.add_runtime_dependency 'asciidoctor-pdf', '~>1.5.3'
  s.add_runtime_dependency 'zip', '~>2.0.2'

  s.add_development_dependency 'rake', '~>13.0.1'
  s.add_development_dependency 'simplecov', '~>0.16.1'
  s.add_development_dependency 'coveralls', '~>0.8.23'
  s.add_development_dependency 'rspec', '~>3.9.0'
  s.add_development_dependency 'webmock', '~>3.9.3'
end
