class UserIconUploader < InatUploader

  self.mappings = DEFAULT_MAPPINGS.merge( {
    icon_type_extension: lambda{ |u, d|
      ext = u.filename.split(".").last.downcase
      unless %w(jpg jpeg png gif).include?(ext)
        ext = u.icon_content_type.split("/").last
      end
      ext
    }
  } )

  # storage :file
  storage :azure_rm

  # equivalent to 2048x2048>
  process resize_to_limit_with_options: [2048 ,2048, { auto_orient: true }]
  process save_content_type_and_size_in_model: [:icon]

  version :large do
    process resize_to_limit_with_options: [500, 500]
  end

  version :medium, from_version: :large do
    process resize_to_limit_with_options: [300, 300]
  end

  # equivalent to 2048x2048#
  version :thumb, from_version: :medium do
    process resize_to_fill_with_options: [48, 48, "Center"]
  end

  version :mini, from_version: :thumb do
    process resize_to_fill_with_options: [16, 16, "Center"]
  end

  def extension_whitelist
    %w(jpg jpeg gif png)
  end

  def default_url(*args)
    version = version_name || paperclip_default_style
    ActionController::Base.helpers.asset_path(
      "attachment_defaults/users/icons/defaults/#{ version }.png" )
  end

  # TODO: cache_dir as well?
  def paperclip_path
    "attachments/users/icons/:id/:style.:icon_type_extension"
  end

end