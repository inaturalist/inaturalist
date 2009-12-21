require 'rubygems'
require File.expand_path(File.join(File.dirname(__FILE__), '../lib/ruby_picasa'))
require 'spec'
require 'mocha'
require 'pp'

def open_file(name)
  open(File.join(File.dirname(__FILE__), File.join('sample', name)))
end

Spec::Runner.configure do |config|
  config.mock_with :mocha
end
