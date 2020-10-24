require_relative './lib/VERSION'

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
  s.version     = GRAFANA_REPORTER_VERSION.join('.')
  s.date        = GRAFANA_REPORTER_RELEASE_DATE
  s.summary     = 'Reporter Service for Grafana'
  s.description = <<~DONE
    Provides a standalone and a webservice frontend for creating reports
    based on asciidoctor, including interfaces to integrate dynamic content
    captured from grafana.

    By default the reports will be converted to PDF documents, whereas other
    target formats can be used as well.
  DONE
  s.author      = 'Christian Kohlmeyer'
  s.email       = 'kohly@gmx.de'
  s.files       = folders.collect { |folder| Dir[File.join(__dir__, 'lib', *folder, '*.rb')].sort }.flatten << 'LICENSE' << 'README.md'
  s.homepage    = 'https://github.com/divinity666/ruby-grafana-reporter'
  s.license     = 'MIT'
  s.executables = 'ruby-grafana-reporter'

  s.metadata = {
    'source_code_uri' => 'https://github.com/divinity666/ruby-grafana-reporter',
    'bug_tracker_uri' => 'https://github.com/divinity666/ruby-grafana-reporter/issues'
  }

  #  s.required_ruby_version = '~>2.5.5'
  s.extra_rdoc_files = ['README.md', 'LICENSE']

  #  s.requirements << 'asciidoctor, ~>2.0'
  #  s.requirements << 'asciidoctor-pdf, ~>1.5'
  #  s.requirements << 'fileutils, ~>1.4'
  #  s.requirements << 'zip, ~>2.0'

  s.bindir = 'bin'

  s.add_runtime_dependency 'asciidoctor', '~>2.0'
  s.add_runtime_dependency 'asciidoctor-pdf', '~>1.5'
  # the following package includes an interface to zip, which is also needed here
  # make sure that supported zip versions match - look in sub-dependency 'gepub'
  #  s.add_runtime_dependency 'asciidoctor-epub3', '~>1.5.0.alpha.18'
  s.add_runtime_dependency 'rubyzip', '>1.1.1', '<2.3'

  s.add_development_dependency 'coveralls', '~>0.8'
  s.add_development_dependency 'rspec', '~>3.9'
  s.add_development_dependency 'simplecov', '~>0.16'
  s.add_development_dependency 'webmock', '~>3.9'
end
