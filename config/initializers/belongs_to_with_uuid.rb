#
# Extends convetional belongs_to relationship to models that have a UUID column
# by allowing assignment by UUID in addition to conventional integer identifiers.
# E.g. observation.taxon_id = "02753980-5640-4a35-8a59-ab5d210877e6" should set
# observation.taxon to the taxon with that UUID (and set observation.taxon_id to
# that taxon's integer identifier). This intent is to work toward a fully
# UUID-based API.
#
# This *should* work with polymorphic relationships like comment.parent, and it
# should not perform any database queries if the assigned value doesn't look
# like a UUID or if the related model doesn't have a UUID column.
#
module BelongsToWithUuid
  UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-5][0-9a-f]{3}-[089ab][0-9a-f]{3}-[0-9a-f]{12}$/i

  extend ActiveSupport::Concern

  class_methods do
    def belongs_to_with_uuid( reflection_name, scope = nil, **options )
      belongs_to( reflection_name, scope, options )
      n, reflection = self.reflections.detect{ |n, reflection| n == reflection_name.to_s}
      if reflection.polymorphic?
        define_method( "#{reflection.foreign_key}=" ) do |value|
          klass = Object.const_get( send( reflection.foreign_type ) )
          if klass.column_names.include?( "uuid" ) && value =~ UUID_PATTERN
            send( "#{reflection_name}=", klass.where( uuid: value ).first )
          else
            super( value )
          end
        end
      else
        define_method( "#{reflection.foreign_key}=" ) do |value|
          klass = reflection.klass
          if klass.column_names.include?( "uuid" ) && value =~ UUID_PATTERN
            send( "#{reflection_name}=", klass.where( uuid: value ).first )
          else
            super( value )
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, BelongsToWithUuid)
