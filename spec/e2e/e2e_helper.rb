# This is loaded once before the first command is executed

require "database_cleaner-active_record"
require "machinist/active_record"
require "faker"
require Rails.root.join( "spec", "blueprints" )

# Adapter that lets cypress-on-rails' SmartFactoryWrapper drive Machinist blueprints.
module MachinistFactory
  def self.create( name, *params )
    attrs = params.last.is_a?( Hash ) ? params.pop : {}
    klass = name.to_s.camelize.constantize
    klass.make!( attrs )
  end

  def self.definition_file_paths=( * ); end
  def self.reload; end
end

require "cypress_on_rails/smart_factory_wrapper"

CypressOnRails::SmartFactoryWrapper.configure(
  always_reload: false,
  factory: MachinistFactory,
  files: [Rails.root.join( "spec", "blueprints.rb" )]
)
