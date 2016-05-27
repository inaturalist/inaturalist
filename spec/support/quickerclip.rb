# inspired by https://gist.github.com/406460 and 
# http://pivotallabs.com/users/rolson/blog/articles/1249-stubbing-out-paperclip-imagemagick-in-tests
# plus some additional monkeypatching to prevent "too many files open" err's
#
# place this file in <app root>/spec/support
#

RSpec.configure do |config|
  $paperclip_stub_size = "800x800"
end

module Paperclip
  class Geometry
    def self.from_file file
      parse($paperclip_stub_size)
    end
  end
  class Thumbnail
    def make
      src = fixture_file_upload('spec/fixtures/files/1x1.png')
      dst = Tempfile.new([@basename, @format].compact.join("."))
      dst.binmode
      FileUtils.cp(src.path, dst.path)
      return dst
    end
  end
  class Attachment
    def post_process(*args)
    end
  end
  module Storage
    module Filesystem
      mattr_accessor :stubbed_for_tests
      self.stubbed_for_tests = true

      alias :_orig_flush_writes :flush_writes
      def flush_writes
        if self.stubbed_for_tests
          @queued_for_write.each{|style, file| file.close}
          @queued_for_write = {}
        else
          _orig_flush_writes
        end
      end
      alias :_orig_flush_deletes :flush_deletes
      def flush_deletes
        if self.stubbed_for_tests
          @queue_for_delete = []
        else
          _orig_flush_deletes
        end
      end
    end
  end
end
