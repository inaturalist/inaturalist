class SiteAdmin < ApplicationRecord

  belongs_to :site, inverse_of: :site_admins
  belongs_to :user, inverse_of: :site_admins
  belongs_to :user

  validates_presence_of :site, :user
  validates_uniqueness_of :user_id, scope: :site_id

  scope :live, -> { joins(:site).merge(Site.live) }
  scope :drafts, -> { joins(:site).merge(Site.drafts) }

end
