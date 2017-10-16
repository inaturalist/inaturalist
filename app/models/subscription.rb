class Subscription < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true, :inverse_of => :update_subscriptions
  belongs_to :user
  belongs_to :taxon # in case this subscription has taxonomic specifity

  blockable_by lambda {|subscription| subscription.resource.try(:user_id) }

  after_save :clear_caches
  after_destroy :clear_caches
  
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

  def self.users_with_unviewed_updates_from(notifier)
    UpdateSubscriber.joins(:update_action).where(update_actions: {
      notifier_type: notifier.class.to_s, notifier_id: notifier.id },
      viewed_at: nil).map(&:subscriber_id)
  end

  def cannot_subscribe_to_north_america
    return unless resource_type == "Place"
    return unless taxon_id.blank?
    if Place.north_america && resource_id == Place.north_america.id
      errors.add(:resource_id, "cannot subscribe to North America without conditions")
    end
  end

  def clear_caches
    ctrl = ActionController::Base.new
    ctrl.send :expire_action, FakeView.home_url( user_id: user_id, ssl: true )
    ctrl.send :expire_action, FakeView.home_url( user_id: user_id, ssl: false )
  end

end
