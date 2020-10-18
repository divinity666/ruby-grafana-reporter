require 'net/http'
require 'fileutils'
require 'yaml'
require 'socket'
require 'uri'
require 'json'
require 'tempfile'
require 'cgi'
require 'optparse'
require 'date'
require 'time'
require 'logger'
require 'asciidoctor'
require 'asciidoctor/extensions'
require 'asciidoctor-pdf'
require 'zip'

# Version information
GRAFANA_REPORTER_VERSION = [0, 1, 5].freeze

folders = [
  %w[grafana],
  %w[grafana_reporter logger],
  %w[grafana_reporter],
  %w[grafana_reporter asciidoctor extensions],
  %w[grafana_reporter asciidoctor],
  %w[grafana_reporter application]
]
folders.each { |folder| Dir[File.join(__dir__, *folder, '*.rb')].sort.each { |file| require_relative file } }
