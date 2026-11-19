# frozen_string_literal: true

# Stubs out Paperclip's ImageMagick work and filesystem writes so specs run
# fast and don't need ImageMagick. Inspired by https://gist.github.com/406460
# and http://pivotallabs.com/users/rolson/blog/articles/1249-stubbing-out-paperclip-imagemagick-in-tests
# plus some additional monkeypatching to prevent "too many files open" errors.
#
# Tag an example or group with `:paperclip_processing` to run the real
# pipeline instead: post-processing, our processors in lib/paperclip_processors,
# ImageMagick, exiftool, and filesystem writes. Writes go to a temp directory
# that is removed after each example, never to public/attachments. Those
# examples need ImageMagick and exiftool installed, like production and CI.

RSpec.configure do | config |
  config.around( :each, :paperclip_processing ) do | example |
    Quickerclip.with_real_processing { example.run }
  end
end

module Quickerclip
  STUB_SIZE = "800x800"

  mattr_accessor :real_processing, default: false

  module GeometryStub
    def from_file( file )
      return super if Quickerclip.real_processing

      parse( STUB_SIZE )
    end
  end

  module ThumbnailStub
    def make
      return super if Quickerclip.real_processing

      src = fixture_file_upload( "spec/fixtures/files/1x1.png" )
      dst = Tempfile.new( [@basename, @format].compact.join( "." ) )
      dst.binmode
      FileUtils.cp( src.path, dst.path )
      dst
    end
  end

  module AttachmentStub
    def post_process( *args )
      super if Quickerclip.real_processing
    end
  end

  # Runs the block with real Paperclip processing and filesystem writes, with
  # every attachment's filesystem path redirected into a temp directory
  def self.with_real_processing
    tmp_root = Dir.mktmpdir( "quickerclip" )
    original_paths = redirect_attachment_paths( tmp_root )
    previously_stubbed = Paperclip::Storage::Filesystem.stubbed_for_tests
    Paperclip::Storage::Filesystem.stubbed_for_tests = false
    self.real_processing = true
    yield
  ensure
    self.real_processing = false
    Paperclip::Storage::Filesystem.stubbed_for_tests = previously_stubbed
    original_paths&.each do | options, path |
      if path.nil?
        options.delete( :path )
      else
        options[:path] = path
      end
    end
    FileUtils.rm_rf( tmp_root ) if tmp_root
  end

  def self.redirect_attachment_paths( tmp_root )
    original_paths = []
    Paperclip::AttachmentRegistry.each_definition do | _klass, _name, options |
      next if options[:storage] && options[:storage].to_sym != :filesystem

      path = options[:path]
      original_paths << [options, path]
      options[:path] = if path.to_s.start_with?( ":rails_root/public" )
        path.sub( ":rails_root/public", tmp_root )
      else
        File.join( tmp_root, ":class/:attachment/:id_partition/:style/:filename" )
      end
    end
    original_paths
  end
end

Paperclip::Geometry.singleton_class.prepend( Quickerclip::GeometryStub )
Paperclip::Thumbnail.prepend( Quickerclip::ThumbnailStub )
Paperclip::Attachment.prepend( Quickerclip::AttachmentStub )

module Paperclip
  module Storage
    module Filesystem
      mattr_accessor :stubbed_for_tests
      self.stubbed_for_tests = true

      alias _orig_flush_writes flush_writes
      def flush_writes
        if stubbed_for_tests
          @queued_for_write.each_value( &:close )
          @queued_for_write = {}
        else
          _orig_flush_writes
        end
      end

      alias _orig_flush_deletes flush_deletes
      def flush_deletes
        if stubbed_for_tests
          @queue_for_delete = []
        else
          _orig_flush_deletes
        end
      end
    end
  end
end
