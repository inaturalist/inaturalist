class Subscription < ApplicationRecord
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
    ctrl.send( :expire_action, UrlHelper.home_url( user_id: user_id, ssl: true ) )
    ctrl.send( :expire_action, UrlHelper.home_url( user_id: user_id, ssl: false ) )
  end
end
