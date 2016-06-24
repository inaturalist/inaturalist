class Announcement < ActiveRecord::Base
  PLACEMENTS = %w(welcome/index users/dashboard users/dashboard#sidebar)
  validates_presence_of :placement, :start, :end, :body

  scope :in_locale, lambda {|locale|
    Rails.logger.debug "[DEBUG] locale: #{locale}"
    where("(? = ANY (locales)) OR locales IS NULL OR locales = '{}'", locale)
  }

  before_save :compact_locales

  def session_key
    "user-seen-ann-#{id}"
  end

  def compact_locales
    self.locales = ( locales || [] ).reject(&:blank?).compact
  end
end
