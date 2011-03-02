require 'rubygems'
require File.expand_path(File.join(File.dirname(__FILE__), '../lib/ruby_picasa'))
require 'rspec'
require 'mocha'
require 'pp'
require 'active_support/core_ext'

def open_file(name)
  open(File.join(File.dirname(__FILE__), File.join('sample', name)))
end

RSpec.configure do |config|
  config.mock_with :mocha
end
