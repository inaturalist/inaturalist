class Subscription < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true
  belongs_to :user
  
  validates_uniqueness_of :user_id, :scope => [:resource_type, :resource_id]
end
