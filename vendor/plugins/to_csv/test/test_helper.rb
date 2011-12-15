begin
  require 'rubygems'
  require 'test/unit'
  require 'active_support'
  require 'active_support/inflector'
  if RUBY_VERSION >= "1.9.0"
    require 'csv'
  else
    require 'fastercsv'
  end
  require File.dirname(__FILE__) + '/../lib/to_csv'
rescue LoadError
  puts 'to_csv tests rely on active_support, and fastercsv if ruby version < 1.9'
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
