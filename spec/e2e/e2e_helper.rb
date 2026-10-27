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
    klass.make!( with_associations( klass, attrs ) )
  end

  # Blueprints set associations like `user { User.make! }`, which would override a passed `user_id`.
  def self.with_associations( klass, attrs )
    attrs.to_h do | key, value |
      reflection = klass.reflect_on_all_associations( :belongs_to ).
        find {| r | !r.polymorphic? && r.foreign_key.to_s == key.to_s }
      reflection ? [reflection.name, reflection.klass.find( value )] : [key, value]
    end
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
