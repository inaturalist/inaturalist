Paperclip.interpolates('icon_type_extension') do |attachment, style|
  ext = attachment.instance.icon_file_name.split('.').last.downcase
  unless %w(jpg jpeg png gif).include?(ext)
    ext = attachment.instance.icon_content_type.split('/').last
  end
  ext
end
