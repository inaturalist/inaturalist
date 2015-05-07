class Subscription < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true, :inverse_of => :update_subscriptions
  belongs_to :user
  belongs_to :taxon # in case this subscription has taxonomic specifity
  
  validates_presence_of :resource, :user
  validates_uniqueness_of :user_id, :scope => [:resource_type, :resource_id, :taxon_id], 
    :message => "has already subscribed to this resource"
  
  cattr_accessor :subscribable_classes
  @@subscribable_classes ||= []

  def to_s
    "<Subscription #{id} user: #{user_id} resource: #{resource_type} #{resource_id}>"
  end

  def has_unviewed_updates_from(notifier)
    Update.elastic_search(where: {
      subscriber_id: user_id, notifier_type: notifier.class.to_s,
      notifier_id: notifier.id
    }, filters: [{ not: { exists: { field: :viewed_at } } }]).total_entries > 0
  end
end
