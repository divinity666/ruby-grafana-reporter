require_relative './lib/VERSION'

folders = [
  %w[],
  %w[grafana],
  %w[grafana_reporter logger],
  %w[grafana_reporter],
  %w[grafana_reporter asciidoctor extensions],
  %w[grafana_reporter asciidoctor],
  %w[grafana_reporter erb],
  %w[grafana_reporter application]
]

Gem::Specification.new do |s|
  s.name        = 'ruby-grafana-reporter'
  s.version     = GRAFANA_REPORTER_VERSION.join('.')
  s.date        = GRAFANA_REPORTER_RELEASE_DATE
  s.summary     = 'Reporter Service for Grafana'
  s.description = 'Build reports based on grafana dashboards in asciidoctor or ERB syntax. '\
                  'Runs as webservice for easy integration with grafana, or as a standalone, '\
                  'command line utility.'
                  ''\
                  'By default the reports will be converted to PDF documents, whereas other '\
                  'target formats are supported as well.'
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

  # the required ruby version is determined from the base docker image, currently debian stretch
  s.required_ruby_version = '>=2.7'
  s.extra_rdoc_files = ['README.md', 'LICENSE']

  s.bindir = 'bin'

  s.add_runtime_dependency 'asciidoctor', '~>2.0'
  s.add_runtime_dependency 'asciidoctor-pdf', '~>2.3'
  # the following package includes an interface to zip, which is also needed here
  # make sure that supported zip versions match - look in sub-dependency 'gepub'
  #  s.add_runtime_dependency 'asciidoctor-epub3', '~>2.1'
  s.add_runtime_dependency 'rubyzip', '>1.1.1', '<2.4'

  s.add_development_dependency 'rspec', '~>3.9'
  s.add_development_dependency 'simplecov', '~>0.16'
  s.add_development_dependency 'coveralls', '~>0.8' if ENV['APPVEYOR']
  s.add_development_dependency 'webmock', '~>3.9'
end
