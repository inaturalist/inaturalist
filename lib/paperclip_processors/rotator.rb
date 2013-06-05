module Paperclip
  class Rotator < Thumbnail
    def transformation_command
      if rotate_command
        super.select{|a| a !~ /auto-orient/} + [rotate_command]
      else
        super
      end
    end
    
    def rotate_command
      target = @attachment.instance
      return if target.rotation.blank?
      " -rotate #{target.rotation}"
    end
  end
end
