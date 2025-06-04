class Subscription < ApplicationRecord
  belongs_to :resource, :polymorphic => true, :inverse_of => :update_subscriptions
  belongs_to :user
  belongs_to :taxon # in case this subscription has taxonomic specifity

  # TODO: uncomment to strictly enforce email confirmation for interaction
  # requires_privilege :interaction, if: proc {| subscription |
  #   subscription.resource_type == "Observation" || resource_type == "User"
  # }, unless: proc {| subscription |
  #   subscription.resource.respond_to?( :user ) && subscription.resource.user.id == subscription.user_id
  # }

  blockable_by proc {| subscription |
    should_bypass_block = subscription.resource.is_a?( TaxonChange ) ||
      ( subscription.resource.is_a?( Flag ) && subscription.resource.flaggable_type == "Taxon" )
    if should_bypass_block
      nil
    else
      subscription.resource.try( :user_id )
    end
  }

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

  def self.users_with_unviewed_updates_from( notifier_updates )
    return [] if notifier_updates.blank?

    subscriber_ids = []
    viewed_subscriber_ids = []
    notifier_updates.each do | result |
      next unless result.try( :es_source )

      subscriber_ids += result.es_source.subscriber_ids
      viewed_subscriber_ids += result.es_source.viewed_subscriber_ids
    end
    subscriber_ids.uniq - viewed_subscriber_ids.uniq
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
