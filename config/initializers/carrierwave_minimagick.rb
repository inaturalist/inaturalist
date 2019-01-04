module CarrierWave
  module MiniMagick
    # check for images that are larger than you probably want
    def validate_dimensions
      manipulate! do |img|
        if img.dimensions.any?{|i| i > 8000 }
          raise CarrierWave::ProcessingError, "dimensions too large"
        end
        img
      end
    end
  end
end
