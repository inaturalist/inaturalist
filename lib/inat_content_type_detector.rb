#
# Custom Paperclip content detector. Generally we want to rely on the file
# command to ensure images get the right content type even if the file name is
# absurd, but it doesn't work for CSS files b/c the file command just views them
# as text/plain, so here we're making an exception for that, even though this
# does open us up to some arbitrary text uploads for places where we allow css.
# It might be necessary to do the same for other other file types in the future.
#
# See config/initializers/paperclip.rb for usage
#
class InatContentTypeDetector
  def initialize(filename)
    @filename = filename
  end

  def detect
    if css?
      "text/css"
    else
      type = type_from_file_command
      # fix for some .m4a audio files in 3GP format coming from smartphones
      if type == "application/octet-stream" &&
         mime_types_for_filename.include?( "audio/mp4" ) &&
         type_from_mime_magic == "video/3gpp"
        return "audio/mp4"
      end
      type
    end
  end

  def css?
    css_filename = mime_types_for_filename.include?( "text/css" )
    css_or_plain_type = ["text/plain", "text/css"].include?( type_from_file_command )
    css_filename && css_or_plain_type
  end

  def type_from_file_command
    @type_from_file_command ||= Paperclip::FileCommandContentTypeDetector.new( @filename ).detect
  end

  def type_from_mime_magic
    @type_from_mime_magic ||= File.open( @filename ) do |file|
      MimeMagic.by_magic( file ).try( :type )
    end
  end

  def mime_types_for_filename
    MIME::Types.type_for( @filename ).collect( &:content_type )
  end
end
