#
# Extends conventional belongs_to relationship to models that have a UUID column
# by allowing assignment by UUID in addition to conventional integer
# identifiers. E.g. observation.taxon_id =
# "02753980-5640-4a35-8a59-ab5d210877e6" should set observation.taxon to the
# taxon with that UUID (and set observation.taxon_id to that taxon's integer
# identifier). This intent is to work toward a fully UUID-based API.
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
        # For polymorphic relationships, we can assign the associate if the
        # foreign key AND the foreign type are known, but if the foreign type
        # hasn't been assigned yet, we stow the UUID in an instance variable and
        # try again when the foreign type gets assigned.
        attr_accessor "#{reflection.foreign_key}_uuid".to_sym

        define_method( "#{reflection.foreign_key}=" ) do |value|
          return super( value ) unless value.to_s =~ UUID_PATTERN
          klass_type = send( reflection.foreign_type )
          klass = Object.const_get( klass_type ) if klass_type
          if klass
            if klass.column_names.include?( "uuid" )
              send( "#{reflection_name}=", klass.where( uuid: value ).first )
            else
              # We might get here if the foreign type changed to a model that
              # doesn't have a UUID column but we're still trying to assign a
              # UUID as a foreign key. In that case, we do nothing and unset the
              # instance variable where we might have had a UUID cached
              send( "#{reflection.foreign_key}_uuid=", nil )
            end
          else
            send( "#{reflection.foreign_key}_uuid=", value )
          end
        end

        # When the foreign type gets assigned, we check to see if we had
        # previously cached a UUID for that relationship and then try UUID-based
        # assignment again
        define_method( "#{reflection.foreign_type}=" ) do |value|
          super( value )
          if uuid = send( "#{reflection.foreign_key}_uuid" )
            send( "#{reflection.foreign_key}=", uuid )
          end
        end
      else
        define_method( "#{reflection.foreign_key}=" ) do |value|
          return super( value ) unless value.to_s =~ UUID_PATTERN
          klass = reflection.klass
          if klass.column_names.include?( "uuid" ) && value =~ UUID_PATTERN
            send( "#{reflection_name}=", klass.where( uuid: value ).first )
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, BelongsToWithUuid)
