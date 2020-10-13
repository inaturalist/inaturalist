class Notification < ActiveRecord::Base

  CATEGORY_PRIORITIES = {
    conversations: 0,
    my_observations: 1,
    others_observations: 2,
    other: 3
  }

  belongs_to :user
  belongs_to :resource, polymorphic: true
  belongs_to :primary_notifier, class_name: "NotificationsNotifier"
  has_many :notifications_notifiers, dependent: :destroy
  has_many :notifiers, through: :notifications_notifiers

  def self.mark_as_read( resource, user_id )
    read_time = Time.now
    NotificationsNotifier.joins( :notification ).
      where( notifications: {
        resource_type: resource.class.name, resource_id: resource.id, user_id: user_id } ).
      update_all( viewed_at: read_time )
    notifiers = NotificationsNotifier.joins( :notification ).
      where( notifications: {
        resource_type: resource.class.name, resource_id: resource.id, user_id: user_id } ).
      where( "read_at IS NULL" )
    notifiers.update_all( read_at: read_time )
    # notifiers.map(&:notification).uniq.each do |n|
    #   n.set_category
    # end
  end

  def self.mark_as_viewed( notifications )
    viewed_time = Time.now
    NotificationsNotifier.where( notification_id: notifications ).
      update_all( viewed_at: viewed_time )
  end

  def mark_as_read
    Notification.mark_as_read( resource, user_id )
  end

  def mark_as_unread
    return if !primary_notifier.read_at?
    NotificationsNotifier.where( notification_id: self.id ).
      where( read_at: primary_notifier.read_at ).
      update_all( read_at: nil )
  end

  def self.delete_all_for_resource( resource )
    Notifier.destroy_all( resource: resource )
    Notification.destroy_all( resource: resource )
  end

  def self.notify_user_for_resource( notifier, user_id, resource, reason = nil )
    notification_attrs = {
      user_id: user_id,
      resource: resource
    }
    notification = Notification.find_or_create_by( notification_attrs )
    notification_notifier_attrs = {
      notification: notification,
      notifier: notifier,
      reason: reason,
    }
    NotificationsNotifier.find_or_create_by( notification_notifier_attrs )
    notification
  end

  def read_state
    return "new" if notifications_notifiers.where( "viewed_at IS NULL" ).any?
    return "read" if primary_notifier.read_at?
    return "unread"
  end

  def is_resource_owner?
    resource.try( :user_id ) == user_id
  end

  def resource_is_observation?
    resource_type == "Observation"
  end

  def resource_is_post?
    resource_type == "Post"
  end

  def resource_is_flag?
    resource_type == "Flag"
  end

  def resource_is_taxon_change?
    resource_type == "TaxonChange"
  end

  def resource_is_listed_taxon?
    resource_type == "ListedTaxon"
  end

  def notifier_is_comment?
    primary_notifier.notifier.resource_type == "Comment" || (
      primary_notifier.notifier.resource_type == "Identification" && primary_notifier.reason == "body"
    )
  end

  def notifier_is_vote?
    primary_notifier.notifier.resource_type == "ActsAsVotable::Vote"
  end

  def notifier_is_observation_field_value?
    primary_notifier.notifier.resource_type == "ObservationFieldValue"
  end

  def highest_priority_notifier
    return if notifications_notifiers.empty?
    now = Time.now
    # sort by:
    #   read time, unread first
    #   category
    #   action priority
    #   action date
    notifications_notifiers.sort_by do |r|
      [r.read_at ? (now - r.read_at) : 0,
        CATEGORY_PRIORITIES[r.category.to_sym],
        r.priority,
        r.notifier.action_date]
    end.first
  end

  def other_primary_notifier_users
    notifications_notifiers.where(
      read_at: primary_notifier.read_at,
      category: primary_notifier.category,
      reason: primary_notifier.reason
    ).map( &:notifier_user ).compact.uniq.
      filter{ |u| u != primary_notifier.notifier_user }
  end

  def most_recent_notifier
    notifications_notifiers.sort_by do |r|
      r.notifier.action_date
    end.last.try( :notifier )
  end

  def self.set_category( notification )
    unless notification.is_a?( Notification )
      notification = Notification.find_by_id( notification )
    end
    return unless notification
    notification.set_category
  end

  def set_category
    priority_notifier = highest_priority_notifier
    return unless priority_notifier
    self.category = priority_notifier.category
    self.notifier_date = most_recent_notifier.action_date
    self.primary_notifier = priority_notifier
    save
  end

  def types
    type_statuses = { }
    notifications_notifiers.each do |nn|
      type_statuses[nn.type] ||= "read"
      if !nn.read_at
        type_statuses[nn.type] = "unread"
      end
    end
    type_statuses
  end

  def as_json( options = nil )
    icon = if resource.respond_to?( "icon" ) && resource.icon.try( :url, :medium )
      resource.icon.url( :medium )
    elsif resource_is_observation? && resource.photos.any?
      resource.photos.first.medium_url
    end
    resource_owner = resource.try( :user )
    primary_notifier_user = primary_notifier.notifier_user
    statement = "#{primary_notifier_user.login}"
    others = other_primary_notifier_users
    if others.length > 0
      statement += " and #{I18n.t( :x_others, count: others.length)}"
    end
    if primary_notifier.reason == "mention"
      statement += " mentioned you in"
    elsif notifier_is_comment?
      statement += " commented on"
    elsif resource_is_observation? && notifier_is_vote?
      statement += " faved"
    elsif resource_is_observation? && notifier_is_observation_field_value?
      statement += " added an observation field value to"
    end
    if resource_is_observation?
      taxon_statement = if resource.taxon
        " of #{resource.taxon.name}"
      end
      if resource_owner == user
        statement += " your observation #{taxon_statement}"
      end
      if resource_owner != user
        statement += " an observation #{taxon_statement} by #{resource_owner.login}"
      end
    elsif resource_is_post?
      if primary_notifier.reason == "created_post"
        statement += " created a journal post"
      elsif primary_notifier.reason == "mention"
        if notifier_is_comment?
          statement += " a comment on a journal post"
        else
          statement += " a journal post"
        end
      elsif notifier_is_comment?
        if is_resource_owner?
          statement += " your post"
        else
          statement += " a journal post"
        end
      end
    elsif resource_is_flag?
      if primary_notifier.reason == "mention"
        if notifier_is_comment?
          statement += " a comment on a flag"
        else
          statement += " a flag"
        end
      elsif notifier_is_comment?
        if is_resource_owner?
          statement += " your flag"
        else
          statement += " a flag"
        end
      end
    elsif resource_is_taxon_change?
      if primary_notifier.reason == "mention"
        if notifier_is_comment?
          statement += " a comment on a taxon change"
        else
          statement += " a taxon change"
        end
      elsif notifier_is_comment?
        if is_resource_owner?
          statement += " your taxon change"
        else
          statement += " a taxon change"
        end
      end
    elsif resource_is_listed_taxon?
      if primary_notifier.reason == "mention"
        if notifier_is_comment?
          statement += " a comment on a listed taxon"
        else
          statement += " a listed taxon"
        end
      elsif notifier_is_comment?
        if is_resource_owner?
          statement += " your listed taxon"
        else
          statement += " a listed taxon"
        end
      end
    end
    url_resource = primary_notifier.notifier.resource
    if url_resource.is_a?( ActsAsVotable::Vote )
      url_resource = url_resource.votable
    end
    {
      id: id,
      type: "notification",
      resource: {
        id: resource_id,
        type: resource_type,
        icon: icon,
        quality_grade: resource_is_observation? ? resource.quality_grade : nil,
        taxon_name: resource_is_observation? ? resource.taxon.try( :name ) : nil,
        owner: resource_owner ? {
          id: resource_owner.id,
          login: resource_owner.login
        } : nil,
      },
      primary_notifier: {
        type: primary_notifier.reason,
        user: {
          id: primary_notifier_user.id,
          login: primary_notifier_user.login
        },
        other_users_count: others.length
      },
      read_state: read_state,
      url: FakeView.url_for( url_resource ),
      statement: statement,
      date: notifier_date,
      category: category,
      types: types
    }
  end

end
