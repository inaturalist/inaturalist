require 'activity_streams'
ActiveRecord::Base.send(:include, ActivityStreams::Acts::ActivityStreamable)
