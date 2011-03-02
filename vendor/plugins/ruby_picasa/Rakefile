# -*- ruby -*-

require 'rubygems'
require 'hoe'
require './lib/ruby_picasa.rb'
require 'rspec'

Hoe.spec('ruby-picasa') do |p|
  p.version = RubyPicasa::VERSION
  p.rubyforge_name = 'ruby-picasa'
  p.developer('pangloss', 'darrick@innatesoftware.com')
  p.extra_deps = 'objectify-xml > 0'
  p.testlib = 'spec'
  p.test_globs = 'spec/**/*_spec.rb'
  p.remote_rdoc_dir = ''
end
