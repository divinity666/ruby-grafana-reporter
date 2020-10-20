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

  s.required_ruby_version = '~>2'
  s.extra_rdoc_files = ['README.md','LICENSE']

  s.requirements << 'asciidoctor, ~>2'
  s.requirements << 'asciidoctor-pdf, ~>1'
  s.requirements << 'zip, ~>2'

  s.bindir = 'bin'

  s.add_runtime_dependency 'asciidoctor', '~>2'
  s.add_runtime_dependency 'asciidoctor-pdf', '~>1'
  s.add_runtime_dependency 'zip', '~>2'
end
