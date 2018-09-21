class Announcement < ActiveRecord::Base
  PLACEMENTS = %w(users/dashboard#sidebar users/dashboard welcome/index)
  has_and_belongs_to_many :sites
  validates_presence_of :placement, :start, :end, :body

  scope :in_locale, lambda {|locale|
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
