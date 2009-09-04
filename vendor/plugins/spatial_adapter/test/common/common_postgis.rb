$:.unshift(File.dirname(__FILE__) + '/../../lib')

require 'rubygems'
require 'activerecord'


ActiveRecord::Base.establish_connection(YAML.load_file(File.dirname(__FILE__) + '/../db/database_postgis.yml'))

require File.dirname(__FILE__) + '/../../init.rb'





                                      




