class Announcement < ActiveRecord::Base
  PLACEMENTS = %w(welcome/index users/dashboard)
  validates_presence_of :placement, :start, :end, :body
end
