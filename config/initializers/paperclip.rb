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

Paperclip.interpolates("icon_type_extension") do |attachment, style|
  ext = attachment.instance.icon_file_name.split(".").last.downcase
  unless %w(jpg jpeg png gif).include?(ext)
    ext = attachment.instance.icon_content_type.split("/").last
  end
  ext
end

Paperclip.interpolates("root_url") do |attachment, style|
  UrlHelper.root_url.chomp( "/" )
end

Paperclip::UploadedFileAdapter.content_type_detector = InatContentTypeDetector
Paperclip::UriAdapter.register
Paperclip::DataUriAdapter.register
