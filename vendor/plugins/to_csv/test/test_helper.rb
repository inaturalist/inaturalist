begin
  require 'rubygems'
  require 'test/unit'
  require 'fastercsv'
  require 'active_support'
  require File.dirname(__FILE__) + '/../lib/to_csv'
rescue LoadError
  puts 'to_csv tests rely on fastercsv, and active_support'
end

class User
  COLUMNS = %w(id name age)
  
  attr_accessor *COLUMNS

  def self.human_attribute_name(attribute)
    attribute.to_s.humanize
  end

  def initialize(params={})
    params.each { |key, value| self.send("#{key}=", value); }
    self
  end

  def attributes
    COLUMNS.inject({}) { |attributes, attribute| attributes.merge(attribute => send(attribute)) }
  end

  def is_old?
    age > 40
  end
end
