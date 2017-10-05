# Remove most metadata from a photo but preserve color profile
# Adapted from
#  https://github.com/thoughtbot/paperclip/blob/master/lib/paperclip/thumbnail.rb
#  https://superuser.com/questions/450838/exiftool-delete-exif-data-but-preserve-some-specific-tags
module Paperclip
  class MetadataFilter < Processor
    def initialize(file, options = {}, attachment = nil)
      super
      @whiny               = options.fetch( :whiny, true )
      @style               = options.fetch( :style )
      @current_format      = File.extname( @file.path )
      @basename            = File.basename( @file.path, @current_format )
    end

    def make
      src = @file
      filename = [@basename, @style, "filtered"].join
      dst_path = File.join( Dir.tmpdir, filename )
      begin
        # Without interpolation, this command looks like this:
        # exiftool -all= -tagsFromFile @ -ICC_Profile input.jpg -o output.jpg
        # That should remove all profiles except the ICC color profile
        Paperclip.run(
          "exiftool",
          "-all= -tagsFromFile @ -ICC_Profile :source -o :dest",
          {
            source: File.expand_path( src.path ),
            dest: File.expand_path( dst_path )
          }
        )
      rescue Cocaine::ExitStatusError => e
        raise Paperclip::Error, "There was an error filtering metadata for #{@basename}: #{e}" if @whiny
      rescue Cocaine::CommandNotFoundError => e
        raise Paperclip::Errors::CommandNotFoundError.new( "Could not run the `exiftool` command. Please install exiftool." )
      end
      # If there were no errors, we should have a new photo at the dst_path
      File.open( dst_path, "rb" )
    end
  end
end
