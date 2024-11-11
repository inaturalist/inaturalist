# frozen_string_literal: true

require "paperclip/media_type_spoof_detector"
# we have a case where zip files have a .ngz extension and
# paperclip doesn"t like this. This is a workaround for
# the resulting error.
# See https://github.com/thoughtbot/paperclip/issues/1470
module Paperclip
  class MediaTypeSpoofDetector
    def spoofed?
      false
    end
  end
end

Paperclip.interpolates( "icon_type_extension" ) do | attachment, _style |
  ext = attachment&.instance&.icon_file_name&.split( "." )&.last&.downcase
  unless %w(jpg jpeg png gif).include?( ext )
    ext = attachment&.instance&.icon_content_type&.split( "/" )&.last
  end
  ext
end

Paperclip.interpolates( "root_url" ) do | _attachment, _style |
  UrlHelper.root_url.chomp( "/" )
end

Paperclip::UploadedFileAdapter.content_type_detector = InatContentTypeDetector
Paperclip::UriAdapter.register
Paperclip::DataUriAdapter.register

module Paperclip
  module Interpolations
    # Perform the actual interpolation. Takes the pattern to interpolate
    # and the arguments to pass, which are the attachment and style name.
    # You can pass a method name on your record as a symbol, which should turn
    # an interpolation pattern for Paperclip to use.
    def self.interpolate( pattern, *args )
      pattern = args.first.instance.send( pattern ) if pattern.is_a? Symbol
      result = pattern.dup
      interpolators_cache.each do | method, token |
        result.gsub!( token ) { send( method, *args ) } if result.include?( token )
      end

      # START OF MODIFICATION
      #
      # for any symbol at least two characters, starting and ending with a letter,
      # and composed of letters or underscopes, if the instance responds to a method
      # with that name, interpolate the pattern replacing that symbol with the result
      # of that method. Allows for dynamic interpolation without having to declare
      # every interpolation pattern individually
      matches = result.scan( /:([a-z][a-z_]*[a-z])/ )
      matches.flatten.uniq.each do | token |
        if args.first.instance.respond_to?( token )
          result.gsub!( ":#{token}" ) { args.first.instance.send( token ) }
        end
      end
      # END OF MODIFICATION

      result
    end
  end
end
