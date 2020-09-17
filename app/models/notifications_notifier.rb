class NotificationsNotifier < ActiveRecord::Base

  TYPE_PRIORITIES = {
    mention: 0,
    comment: 1,
    flag: 2,
    quality_grade: 3,
    dqa: 4,
    community_id: 5,
    annotation: 6,
    fave: 7
  }

  belongs_to :notification
  belongs_to :notifier
  before_save :set_category
  after_save :set_notification_category
  after_destroy :delete_orphaned_notification
  after_destroy :delete_orphaned_notifier
  after_destroy :set_notification_category

  def priority
    TYPE_PRIORITIES[type] || 100
  end

  def type
    # mention, comment, flag, community id, obs field/annotation, fave
    if reason == "mention"
      return :mention
    elsif notifier.resource_type == "Comment"
      return :comment
    elsif notifier.resource_type == "ActsAsVotable::Vote"
      return :fave
    end
  end

  def set_notification_category
    notification.set_category if notification
  end

  def set_category
    self.category = category
  end

  def delete_orphaned_notification
    if notification.notifications_notifiers.empty?
      notification.destroy
    end
  end

  def delete_orphaned_notifier
    if notifier.notifications_notifiers.empty?
      notifier.destroy
    end
  end

  def category
    # mentions, comments on their observations, ID bodies
    if reason == "mention" ||
        notifier.resource_type == "Comment" ||
        ( notifier.resource_type == "Identification" && reason == "body" )
      return :conversations
    elsif notification.resource_type === "Observation"
      if notification.is_resource_owner?
        return :my_observations
      else
        return :others_observations
      end
    end
    :other
  end

  def notifier_user
    notifier.resource.try( :user )
  end

end