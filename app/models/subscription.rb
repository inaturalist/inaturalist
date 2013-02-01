class Subscription < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true
  belongs_to :user
  belongs_to :taxon # in case this subscription has taxonomic specifity
  
  validates_presence_of :resource, :user
  validates_uniqueness_of :user_id, :scope => [:resource_type, :resource_id], 
    :message => "has already subscribed to this resource"
  
  cattr_accessor :subscribable_classes
  @@subscribable_classes ||= []

  def to_s
    "<Subscription #{id} user: #{user_id} resource: #{resource_type} #{resource_id}>"
  end

  def has_unviewed_updates_from(notifier)
    Update.exists?([
      "subscriber_id = ? AND notifier_type = ? AND notifier_id = ? AND viewed_at IS NULL",
      user_id,
      notifier.class.to_s,
      notifier.id
    ])
  end
end
