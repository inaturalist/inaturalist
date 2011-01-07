require 'paperclip'

require 'delayed/paperclip'
require 'delayed/jobs/resque_paperclip_job'
require 'delayed/jobs/delayed_paperclip_job'

if Object.const_defined?("ActiveRecord")
  ActiveRecord::Base.send(:include, Delayed::Paperclip)
end