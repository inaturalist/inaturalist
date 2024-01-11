# frozen_string_literal: true

module PaperclipPathVersioning
  extend ActiveSupport::Concern

  included do
    def paperclip_versioned_path( attachment_name )
      attachment_paths_constant = "PAPERCLIP_#{attachment_name.upcase}_PATHS"
      unless self.class.const_defined?( attachment_paths_constant )
        raise "`#{self.class.name}` has not implemented `PaperclipPathVersioning` on attachment " \
          "`#{attachment_name}`"
      end
      attachment_path_versions = self.class.const_get( attachment_paths_constant )
      path_version = send( "#{attachment_name}_path_version" )
      versioned_path = attachment_path_versions[path_version]
      if versioned_path.nil?
        raise "`#{self.class.name}` implemented `PaperclipPathVersioning` but does not have a " \
          "path version `#{path_version}` on attachment `#{attachment_name}`"
      end
      versioned_path
    end

    class << self
      def paperclip_path_versioning( attachment_name, path_patterns )
        attachment_updated_at_method = "#{attachment_name}_updated_at"
        attachment_path_version_method = "#{attachment_name}_path_version"
        unless column_names.include?( attachment_updated_at_method )
          raise "`#{name}` cannot implement `PaperclipPathVersioning` on attachment " \
            "`#{attachment_name}` as it is missing column `#{attachment_updated_at_method}`"
        end
        unless column_names.include?( attachment_path_version_method )
          raise "`#{name}` cannot implement `PaperclipPathVersioning` on attachment " \
            "`#{attachment_name}` as it is missing column `#{attachment_path_version_method}`"
        end
        unless path_patterns.is_a?( Array ) && path_patterns.size >= 2
          raise "`#{name}` cannot implement `PaperclipPathVersioning` on attachment " \
            "`#{attachment_name}` as `path_patterns` needs to be an array of at least 2 paths"
        end

        const_set( "PAPERCLIP_#{attachment_name.upcase}_PATHS", path_patterns )

        before_save -> do
          attachment_changed_method = "#{attachment_updated_at_method}_changed?"
          return unless send( attachment_changed_method )

          send( "#{attachment_path_version_method}=", path_patterns.size - 1 )
        end

        define_method( "#{attachment_name}_version" ) do
          Digest::MD5.hexdigest( send( attachment_updated_at_method ).to_i.to_s )
        end
      end
    end
  end
end

ActiveRecord::Base.include( PaperclipPathVersioning )
