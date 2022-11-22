class GuideUser < ApplicationRecord
  belongs_to :guide, :inverse_of => :guide_users
  belongs_to :user, :inverse_of => :guide_users
  validates_presence_of :guide, :user
  validates_uniqueness_of :user_id, :scope => :guide_id
end
