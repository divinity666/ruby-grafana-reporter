require_relative 'stubs/webmock'
Dir["spec/models/*.rb"].each {|f| require_relative "../#{f}"}
Dir["spec/integration/*.rb"].each {|f| require_relative "../#{f}"}
