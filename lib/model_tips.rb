#--
# My awesome attempt attempt to add a bit of metadata / UI help in the model. 
# Here's how it works: in your model, define help_txt and instructions like
# this:
#
#   instruction_for :place_guess, "Type the name of a place"
#   help_txt_for :place_guess, <<-DESC
#     Enter the name of a place and we'll try to find where it is. If we find
#     it, you can drag the map marker around to get more specific.
#   DESC
# 
# Now you can access them in your views or validators like this:
# 
#   ModelName.instructions[:place_guess]
#   ModelName.help_txt[:place_guess]
# 
#++
module ModelTips  
  module ActiveRecord
    def self.included(ar)
      ar.extend ClassMethods
    end

    module ClassMethods
      #
      # Help text entries are longer-format descriptions describing an 
      # attribute.
      #
      # (perhaps used as a tooltip?)
      #
      def help_txt
        if read_inheritable_attribute(:help_txt).nil?
          write_inheritable_attribute(:help_txt, {})
        end
        read_inheritable_attribute(:help_txt)
      end
      
      #
      # Instructions are short, 1-sentence descriptions of an attribute.  We
      # often use them in an attributes form field itself, so you'll probably
      # want to scrub this value before saving an object.
      #
      def instructions
        if read_inheritable_attribute(:instructions).nil?
          write_inheritable_attribute(:instructions, {})
        end
        read_inheritable_attribute(:instructions)
      end

      def help_txt_for(attribute, msg)
        help_txt[attribute.to_sym] = msg
      end

      def instruction_for(attribute, msg)
        instructions[attribute.to_sym] = msg
      end
    end
  end
end
ActiveRecord::Base.send(:include, ModelTips::ActiveRecord)