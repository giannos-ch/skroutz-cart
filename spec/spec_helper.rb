require 'bundler/setup'
require 'webmock/rspec'
require 'tmpdir'
require 'tempfile'

# Add lib/ to the load path so specs can require 'skroutz_cart/...' directly
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

WebMock.disable_net_connect!
