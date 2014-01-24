class SiteAdmin < ActiveRecord::Base
  attr_accessible :site_id, :user_id
  belongs_to :site, :inverse_of => :site_admins
  belongs_to :user, :inverse_of => :user
end
