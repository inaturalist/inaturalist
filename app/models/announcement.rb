class Announcement < ActiveRecord::Base
  PLACEMENTS = %w(welcome/index users/dashboard users/dashboard#sidebar)
  validates_presence_of :placement, :start, :end, :body

  scope :in_locale, lambda {|locale| where("locale = ? OR locale IS NULL OR locale = ''", locale)}

  def session_key
    "user-seen-ann-#{id}"
  end
end
