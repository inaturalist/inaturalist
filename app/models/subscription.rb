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
    es_response = UpdateAction.elastic_search(
      filters: [
        { term: { notifier_type: notifier.class.to_s } },
        { term: { notifier_id: notifier.id } }
      ],
      sort: { id: :desc }
    ).per_page(100).page(1)
    if es_response && es_response.results
      subscriber_ids = []
      viewed_subscriber_ids = []
      es_response.results.each do |result|
        subscriber_ids += result.subscriber_ids
        viewed_subscriber_ids += result.viewed_subscriber_ids
      end
      return subscriber_ids.uniq - viewed_subscriber_ids.uniq
    end
    []
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

  # Whether or not this subscription should be suspended based on how much the
  # subscriber actually views the observations they get notified about. Has the
  # somewhat serious flaw that place subscriptions with a taxon sort of get
  # ignored in that the count of unviewed updates is for *all* updates for that
  # resource for that user, not just updates for that resource for that user
  # that were generated for a taxon preference. So if you subscribe to snakes of
  # California and squirrels of California, and you have 600 unviewed snake
  # updates from CA and 600 unviewed squirrel updates from CA, you will just
  # stop getting any updates about anything from CA
  def suspended?
    return false unless %w{Place Taxon}.include?( resource_type )
    return true if suspended_at < 1.day.ago
    unviewed_count_for_resource = UpdateAction.elastic_search(
      size: 0,
      filters: [
        {
          term: {
            resource_type: resource_type
          }
        },
        {
          term: {
            resource_id: resource_id
          }
        }
      ],
      inverse_filters: [
        {
          terms: {
            viewed_subscriber_ids: [user_id]
          }
        }
      ]
    ).results.total_entries
    if unviewed_count_for_resource > 1000
      update_attribute( :suspended_at, Time.now )
    else
      update_attribute( :suspended_at, nil )
    end
  end

end
