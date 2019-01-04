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
  ext = "jpg" if ext == "jpeg"
  ext
end

# override content_type_extension to turn .jpeg into .jpg
Paperclip.interpolates("content_type_extension") do |attachment, style_name|
  mime_type = MIME::Types[attachment.content_type]
  extensions_for_mime_type = unless mime_type.empty?
    mime_type.first.extensions
  else
    []
  end

  original_extension = extension(attachment, style_name)
  style = attachment.styles[style_name.to_s.to_sym]
  ext = if style && style[:format]
    style[:format].to_s
  elsif extensions_for_mime_type.include? original_extension
    original_extension
  elsif !extensions_for_mime_type.empty?
    extensions_for_mime_type.first.dup
  else
    # It's possible, though unlikely, that the mime type is not in the
    # database, so just use the part after the '/' in the mime type as the
    # extension.
    %r{/([^/]*)\z}.match(attachment.content_type)[1]
  end
  ext.downcase!
  ext = "jpg" if ext == "jpeg"
  ext
end

Paperclip.interpolates("root_url") do |attachment, style|
  FakeView.root_url.chomp("/")
end

Paperclip::UploadedFileAdapter.content_type_detector = InatContentTypeDetector
Paperclip::UriAdapter.register
Paperclip::DataUriAdapter.register
