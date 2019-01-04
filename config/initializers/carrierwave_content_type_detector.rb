# Essentially a fork of carrierwave-mimetype-fu
# Pre-forked code Copyright 2011, Sebastian Tschan
# https://github.com/deviantech/carrierwave-mimetype-fu
# Originally licensed under the MIT license

module CarrierWave
  module ContentTypeDetector
    extend ActiveSupport::Concern

    included do
      mod = Module.new do
        def cache!(new_file = sanitized_file)
          # Only step in on the initial file upload
          opened_file = case new_file
            when CarrierWave::Uploader::Download::RemoteFile then
              new_file.send(:file)
            when ActionDispatch::Http::UploadedFile then
              File.open(new_file.path)
            when File then
              new_file
            else
              nil
          end

          return super(new_file) unless opened_file

          begin
            real_content_type = InatContentTypeDetector.new(opened_file.path).detect
            valid_extensions  = Array(MIME::Types[real_content_type].try(:first).try(:extensions))

            # Set proper content type, and update filename if current name doesn't match reach content type
            new_file              = CarrierWave::SanitizedFile.new(new_file)
            new_file.content_type = real_content_type
            base, ext             = new_file.send(:split_extension, new_file.original_filename)
            ext                   = valid_extensions.first unless valid_extensions.include?(ext)

            # all .jpg and .jpeg files should be stored as .jpg
            ext = "jpg" if ext == "jpeg"
            new_file.instance_variable_set '@original_filename', [base, ext].join('.')
          rescue StandardError => e
            Rails.logger.warn "[CarrierWave::InatContentTypeDetector] errors: #{e}"
          ensure
            super(new_file)
          end
        end
      end

      prepend mod

    end
  end
end
