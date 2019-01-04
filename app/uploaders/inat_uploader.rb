class InatUploader < CarrierWave::Uploader::Base

  include CarrierWave::MiniMagick
  include CarrierWave::Compatibility::Paperclip
  include CarrierWave::ContentTypeDetector

  process :validate_dimensions
  process flatten_gif: [ ]
  process metadata_filter: [ ]

  def file?
    !file.nil?
  end

  def url(*args)
    if args[0] && args[0] == :original
      return url
    end
    super
  end

  def metadata_filter
    return unless ( current_path && File.file?( current_path ) )
    exif_command = "exiftool -all= -tagsFromFile @ -ICC_Profile #{current_path}"
    Rails.logger.debug "[DEBUG] #{exif_command}"
    system exif_command
  end

  def flatten_gif
    manipulate! do |img|
      if img.mime_type.match /gif/
        img.collapse!
      end
      img
    end
  end

  def resize_to_limit_with_options(width, height, options = { })
    width = dimension_from width
    height = dimension_from height
    manipulate! do |img|
      img.combine_options do |cmd|
        cmd.auto_orient if options[:auto_orient]
        cmd.resize "#{width}x#{height}>"
      end
      img
    end
  end

  def resize_to_fill_with_options(width, height, gravity = "Center", options = { })
    width = dimension_from width
    height = dimension_from height
    manipulate! do |img|
      cols, rows = img[:dimensions]
      img.combine_options do |cmd|
        if width != cols || height != rows
          scale_x = width/cols.to_f
          scale_y = height/rows.to_f
          if scale_x >= scale_y
            cols = (scale_x * (cols + 0.5)).round
            rows = (scale_x * (rows + 0.5)).round
            cmd.resize "#{cols}"
          else
            cols = (scale_y * (cols + 0.5)).round
            rows = (scale_y * (rows + 0.5)).round
            cmd.resize "x#{rows}"
          end
        end
        cmd.gravity gravity
        cmd.background "rgba(255,255,255,0.0)"
        cmd.extent "#{width}x#{height}" if cols != width || rows != height
        cmd.repage.+
        cmd.auto_orient if options[:auto_orient]
      end
      img
    end
  end

  def save_content_type_and_size_in_model(name)
    model.send("#{name}_content_type=", file.content_type.blank? ? nil : file.content_type)
    model.send("#{name}_file_size=", file.size)
  end

end
