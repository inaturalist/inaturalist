class SiteAdmin < ActiveRecord::Base
  belongs_to :site, :inverse_of => :site_admins
  belongs_to :user, :inverse_of => :user
end
