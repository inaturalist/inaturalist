# Include hook code here
require 'acts_as_flaggable'
ActiveRecord::Base.send(:include, Gonzo::Acts::Flaggable)
