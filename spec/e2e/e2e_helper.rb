# This is loaded once before the first command is executed

begin
  require 'database_cleaner-active_record'
rescue LoadError => e
  puts e.message
  begin
    require 'database_cleaner'
  rescue LoadError => e
    puts e.message
  end
end

begin
  require 'factory_bot_rails'
rescue LoadError => e
  puts e.message
  begin
    require 'factory_girl_rails'
  rescue LoadError => e
    puts e.message
  end
end

# Load Machinist blueprints and MakeHelpers (mirrors spec/spec_helper.rb)
require 'machinist/active_record'
require 'faker'
require Rails.root.join('spec', 'helpers', 'make_helpers')
include MakeHelpers
require Rails.root.join('spec', 'blueprints')

# Adapter that maps SmartFactoryWrapper's interface to Machinist's .make! / .make
module MachinistFactory
  def self.create(name, *params)
    attrs = params.last.is_a?(Hash) ? params.pop : {}
    blueprint_name = params.first.is_a?(Symbol) ? params.shift : nil
    klass = name.to_s.camelize.constantize
    blueprint_name ? klass.make!(blueprint_name, attrs) : klass.make!(attrs)
  end

  def self.create_list(name, count, *params)
    count.to_i.times.map { create(name, *params.deep_dup) }
  end

  def self.build(name, *params)
    attrs = params.last.is_a?(Hash) ? params.pop : {}
    blueprint_name = params.first.is_a?(Symbol) ? params.shift : nil
    klass = name.to_s.camelize.constantize
    blueprint_name ? klass.make(blueprint_name, attrs) : klass.make(attrs)
  end

  def self.build_list(name, count, *params)
    count.to_i.times.map { build(name, *params.deep_dup) }
  end

  def self.definition_file_paths=(*); end
  def self.reload; end
end

require 'cypress_on_rails/smart_factory_wrapper'

CypressOnRails::SmartFactoryWrapper.configure(
    always_reload: false,
    factory: MachinistFactory,
    files: [
      Rails.root.join('spec', 'blueprints.rb')
    ]
)
