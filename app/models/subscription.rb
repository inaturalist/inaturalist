class Subscription < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true
  belongs_to :user
  belongs_to :taxon # in case this subscription has taxonomic specifity
  
  validates_uniqueness_of :user_id, :scope => [:resource_type, :resource_id], 
    :message => "has already subscribed to this resource"
  
  def has_unviewed_updates_from(notifier)
    Update.exists?([
      "subscriber_id = ? AND notifier_type = ? AND notifier_id = ? AND viewed_at IS NULL",
      user_id,
      notifier.class.to_s,
      notifier.id
    ])
  end
end
