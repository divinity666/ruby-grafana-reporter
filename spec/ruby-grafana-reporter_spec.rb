require_relative 'stubs/webmock'

RSpec.configure do |config|
  config.color = true
  config.tty = true
  config.formatter = :documentation
end

Dir["spec/models/*.rb"].each {|f| require_relative "../#{f}"}
Dir["spec/integration/*.rb"].each {|f| require_relative "../#{f}"}
