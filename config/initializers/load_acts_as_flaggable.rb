# Include hook code here
require 'acts_as_flaggable/acts_as_flaggable'
require 'acts_as_flaggable/flag'
ActiveRecord::Base.send(:include, Gonzo::Acts::Flaggable)

module Gonzo
  module Acts
    module Flaggable
      module InstanceMethods

        def flagged?
          if self.flags.loaded?
            !! self.flags.detect{ |f| !f.resolved }
          else
            self.flags.where(resolved: false).any?
          end
        end

        def to_plain_s
          s = "#{self.class} #{self.try_methods(:name, :title)}"
        end

      end
    end
  end
end
