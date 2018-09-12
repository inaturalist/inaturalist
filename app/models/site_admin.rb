class SiteAdmin < ActiveRecord::Base

  belongs_to :site, inverse_of: :site_admins
  belongs_to :user

  validates_presence_of :site, :user
  validates_uniqueness_of :user_id, scope: :site_id

end
