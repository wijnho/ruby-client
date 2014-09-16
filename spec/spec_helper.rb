require 'vcr'
require 'webmock/rspec'
require 'Zumata'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.allow_http_connections_when_no_cassette = true
end

RSpec.configure do |config|
  config.color = true
  config.formatter = :documentation
  config.failure_color = :magenta
end