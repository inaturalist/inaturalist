class Subscription < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true, :inverse_of => :update_subscriptions
  belongs_to :user
  belongs_to :taxon # in case this subscription has taxonomic specifity
  
  validates_presence_of :resource, :user
  validates_uniqueness_of :user_id, :scope => [:resource_type, :resource_id, :taxon_id], 
    :message => "has already subscribed to this resource"
  validate :cannot_subscribe_to_north_america

  cattr_accessor :subscribable_classes
  @@subscribable_classes ||= []

  scope :with_unsuspended_users, -> {
    joins(:user).where(users: { subscriptions_suspended_at: nil }) }

  def to_s
    "<Subscription #{id} user: #{user_id} resource: #{resource_type} #{resource_id}>"
  end

  def has_unviewed_updates_from(notifier)
    Update.exists?([
      "subscriber_id = ? AND notifier_type = ? AND notifier_id = ? AND viewed_at IS NULL",
      user_id, notifier.class.to_s, notifier.id ])
    # this is the elasticsearch way of doing the same
    # Update.elastic_search(where: {
    #   subscriber_id: user_id, notifier_type: notifier.class.to_s,
    #   notifier_id: notifier.id
    # }, filters: [{ not: { exists: { field: :viewed_at } } }]).total_entries > 0
  end

  def cannot_subscribe_to_north_america
    return unless resource_type == "Place"
    return unless taxon_id.blank?
    if Place.north_america && resource_id == Place.north_america.id
      errors.add(:resource_id, "cannot subscribe to North America without conditions")
    end
  end

end
