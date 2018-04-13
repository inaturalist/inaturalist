class UpdateAction < ActiveRecord::Base

  include ActsAsElasticModel

  belongs_to :resource, polymorphic: true
  belongs_to :notifier, polymorphic: true
  belongs_to :resource_owner, class_name: "User"
  has_many :update_subscribers, dependent: :delete_all

  validates_presence_of :resource, :notifier

  before_create :set_resource_owner

  YOUR_OBSERVATIONS_ADDED = "your_observations_added"

  def to_s
    "<UpdateAction #{id} resource_type: #{resource_type} " +
      "resource_id: #{resource_id} notifier_type: #{notifier_type} notifier_id: #{notifier_id}>"
  end

  def set_resource_owner
    return if self.resource_owner_id
    self.resource_owner = resource && resource.respond_to?(:user) ? resource.user : nil
  end

  def bulk_insert_subscribers(subscriber_ids)
    potential_subscriber_ids = subscriber_ids
    notifier_user = notifier if notifier.is_a?( User )
    notifier_user ||= notifier.try(:user)
    if notifier_user
      excepted_user_ids = UserBlock.
        where( "user_id = ? OR blocked_user_id = ?", notifier_user.id, notifier_user.id ).
        pluck(:user_id, :blocked_user_id).flatten.uniq
      excepted_user_ids += UserMute.where( muted_user_id: notifier_user.id ).pluck(:user_id)
      potential_subscriber_ids = potential_subscriber_ids - excepted_user_ids.uniq
    end
    values = potential_subscriber_ids.compact.map{ |id| "(#{self.id},#{id})" }
    return if values.blank?
    sql = "INSERT INTO update_subscribers (update_action_id, subscriber_id) " +
          "VALUES #{ values.join(",") }"
    UpdateAction.connection.execute(sql)
  end

  def sort_by_date
    created_at || notifier.try(:created_at) || Time.now
  end

  def self.components_of_class(klass, updates)
    (updates.map{ |u| u.resource && u.resource_type == klass.name ? u.resource : nil } +
      updates.map{ |u| u.notifier && u.notifier_type == klass.name ? u.notifier : nil }).
      compact.uniq
  end

  def self.components_with_assoc(assoc, updates)
    (updates.map{ |u| u.resource && u.resource.class.reflect_on_association(assoc) ? u.resource : nil } +
      updates.map{ |u| u.notifier && u.notifier.class.reflect_on_association(assoc) ? u.notifier : nil }).
      compact.uniq
  end


  def self.email_updates
    start_time = 1.day.ago.utc
    end_time = Time.now.utc
    user_ids = UpdateAction.joins(:update_subscribers).
      where(["created_at BETWEEN ? AND ?", start_time, end_time]).
      select("DISTINCT subscriber_id").map{|u| u.subscriber_id}.compact.uniq.sort
    user_ids.each do |subscriber_id|
      UpdateAction.delay(priority: INTEGRITY_PRIORITY, queue: "slow",
        unique_hash: { "UpdateAction::email_updates_to_user": subscriber_id }).
        email_updates_to_user(subscriber_id, start_time, end_time)
    end
  end

  def self.email_updates_to_user(subscriber, start_time, end_time)
    user = subscriber
    user = User.find_by_id(subscriber.to_i) unless subscriber.is_a?(User)
    user ||= User.find_by_login(subscriber)
    return unless user.is_a?(User)
    return if user.email.blank?
    User.preload_associations(user, :stored_preferences)
    return if user.prefers_no_email
    return unless user.active? # email verified
    updates = UpdateAction.elastic_paginate(
      filters: [
        { term: { subscriber_ids: user.id } },
        { range: { created_at: { gte: start_time } } },
        { range: { created_at: { lte: end_time } } }
      ],
      per_page: 100,
      sort: { id: :asc })
    updates = updates.to_a.delete_if do |u|
      !user.prefers_project_journal_post_email_notification? && u.resource_type == "Project" && u.notifier_type == "Post" ||
      !user.prefers_comment_email_notification? && u.notifier_type == "Comment" ||
      !user.prefers_identification_email_notification? && u.notifier_type == "Identification" ||
      !user.prefers_mention_email_notification? && u.notification == "mention" ||
      !user.prefers_project_added_your_observation_email_notification? && u.notification == "your_observations_added" ||
      !user.prefers_project_curator_change_email_notification? && u.notification == "curator_change" ||
      !user.prefers_taxon_change_email_notification? && u.notification == "committed" ||
      !user.prefers_user_observation_email_notification? && u.notification == "created_observations" ||
      !user.prefers_taxon_or_place_observation_email_notification? && u.notification == "new_observations"
    end.compact
    return if updates.blank?

    UpdateAction.preload_associations(updates, [ :resource, :notifier, :resource_owner ] )
    obs = UpdateAction.components_of_class(Observation, updates)
    ids = UpdateAction.components_of_class(Identification, updates)
    with_users = UpdateAction.components_with_assoc(:user, updates)
    Observation.preload_associations(obs, [:photos, :site ])
    Taxon.preload_associations(ids + obs, { taxon: [ :photos, { taxon_names: :place_taxon_names } ] } )
    User.preload_associations(with_users, { user: :site })
    updates.delete_if{ |u| u.resource.nil? || u.notifier.nil? }
    Emailer.updates_notification(user, updates).deliver_now
  end

  def self.load_additional_activity_updates(updates, user_id)
    # fetch all other activity updates for the loaded resources
    activity_updates = updates.select{ |u| u.notification == "activity" }
    return updates if activity_updates.blank?
    action_ids = activity_updates.map{ |u| u.id }
    clauses = []
    activity_updates.each do |update|
      clauses << "(resource_type = '#{update.resource_type}' AND resource_id = #{update.resource_id})"
    end
    conditions = ["notification = 'activity' AND update_actions.id NOT IN (?)", action_ids]
    conditions[0] += " AND (#{clauses.join(' OR ')})" unless clauses.blank?
    updates += UpdateAction.joins(:update_subscribers).where(conditions).
      where("update_subscribers.subscriber_id = ?", user_id)
    updates
  end

  def self.group_and_sort(updates, options = {})
    grouped_updates = []
    updates.group_by{|u| [u.resource_type, u.resource_id, u.notification]}.each do |key, batch|
      resource_type, resource_id, notification = key
      batch = batch.sort_by{|u| u.sort_by_date}
      if options[:hour_groups] && "created_observations new_observations".include?(notification.to_s) && batch.size > 1
        batch.group_by{|u| u.created_at.strftime("%Y-%m-%d %H")}.each do |hour, hour_updates|
          grouped_updates << [key, hour_updates]
        end
      elsif notification == "activity" && !options[:skip_past_activity]
        # get the resource that has all this activity
        resource = batch.first.resource
        if resource.blank?
          Rails.logger.error "[ERROR #{Time.now}] couldn't find resource #{resource_type} #{resource_id}, first update: #{batch.first}"
          next
        end

        # get the associations on that resource that generate activity updates
        activity_assocs = resource.class.notifying_associations.select do |assoc, assoc_options|
          assoc_options[:notification] == "activity"
        end

        # create pseudo updates for all activity objects
        activity_assocs.each do |assoc, assoc_options|
          # this is going to lazy load assoc's of the associate (e.g. a comment's user) which might not be ideal
          resource.send(assoc).each do |associate|
            unless batch.detect{|u| u.notifier_type == associate.class.name && u.notifier_id == associate.id}
              batch << UpdateAction.new(:resource => resource, :notifier => associate, :notification => "activity")
            end
          end
        end
        grouped_updates << [key, batch.sort_by{|u| u.sort_by_date}]
      else
        grouped_updates << [key, batch]
      end
    end
    grouped_updates.sort_by {|key, updates| updates.last.sort_by_date.to_i * -1}
  end

  def self.user_viewed_updates(updates, user_id)
    updates = updates.to_a.compact
    return if updates.blank?
    # mark all as viewed
    action_ids = updates.map(&:id)
    UpdateSubscriber.where(update_action_id: action_ids).
      where(subscriber_id: user_id).
      update_all(viewed_at: Time.now)
    UpdateAction.elastic_index!(ids: action_ids)
  end

  def self.delete_and_purge(*args)
    return if args.blank?
    # first delete all entries from Elasticearch
    UpdateAction.where(*args).select(:id).find_in_batches do |batch|
      ids = batch.map(&:id)
      if ids.any?
        UpdateAction.elastic_delete!(filters: [ { terms: { id: ids } } ])
        UpdateSubscriber.delete_all(update_action_id: ids)
      end
    end
    # then delete them from Postgres
    UpdateAction.delete_all(*args)
  end

  def self.first_with_attributes(attrs, options = {})
    skip_validations = options.delete(:skip_validations)
    # using .limit(1)[0] rather than .first to avoid a SQL sort on id
    if action = UpdateAction.where(attrs).limit(1)[0]
      return action
    end
    action = UpdateAction.new(attrs.merge(created_at: Time.now).merge(options))
    if !action.save(validate: !skip_validations)
      return
    end
    return action
  end
end
