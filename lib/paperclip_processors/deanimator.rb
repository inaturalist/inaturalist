# Use only the first frame of animated gifs
module Paperclip
  class Deanimator < Thumbnail
    def transformation_command
      if @attachment.original_filename.to_s =~ /\.gif/ || @attachment.content_type == "image/gif"
        super + [" -delete 1--1"]
      else
        super
      end
    end
  end
end
