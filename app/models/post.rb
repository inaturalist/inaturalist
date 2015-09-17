class Post < ActiveRecord::Base
  acts_as_spammable :fields => [ :title, :body ],
                    :comment_type => "item-description"

  has_subscribers
  notifies_subscribers_of :parent, {
    :on => [:update, :create],
    :queue_if => lambda{ |post|
      conditions = { notifier_type: "Post", notifier_id: post.id }
      existing_updates_count = Update.where(conditions).count
      # destroy existing updates if user *unpublishes* a post
      if post.draft? && existing_updates_count > 0
        Update.delete_and_purge(conditions)
        return false
      end
      return !post.draft? && existing_updates_count == 0
    },
    :if => lambda{|post, project, subscription|
      return true unless post.parent_type == 'Project'
      project_user = project.project_users.where(user_id: subscription.user_id).first
      project_user.prefers_updates?
    },
    :notification => "created_post",
    :include_notifier => true
  }
  notifies_users :mentioned_users, on: :save, notification: "mention"
  belongs_to :parent, :polymorphic => true
  belongs_to :user
  has_many :comments, :as => :parent, :dependent => :destroy
  has_and_belongs_to_many :observations, -> { uniq }
  
  validates_length_of :title, :in => 1..2000
  validates_presence_of :parent
  validate :user_must_be_on_site_long_enough
  
  before_save :skip_update_for_draft
  after_create :increment_user_counter_cache
  after_destroy :decrement_user_counter_cache
  
  scope :published, -> { where("published_at IS NOT NULL") }
  scope :unpublished, -> { where("published_at IS NULL") }

  ALLOWED_TAGS = %w(
    a abbr acronym b blockquote br cite code dl dt em embed h1 h2 h3 h4 h5 h6 hr i
    iframe img li object ol p param pre small strong sub sup tt ul
    table tr td th
    audio source
  )

  ALLOWED_ATTRIBUTES = %w(
    href src width height alt cite title class name xml:lang abbr value align style controls preload
  )

  def user_must_be_on_site_long_enough
    if !is_a?(Trip) && published? && user.created_at > 24.hours.ago
      errors.add(:user, :must_be_on_site_long_enough)
    end
  end
  
  def skip_update_for_draft
    @skip_update = true if draft?
    true
  end
  
  # Update the counter cache in users.
  def increment_user_counter_cache
    self.user.increment!(:journal_posts_count) if parent_type == 'User' && published?
    true
  end
  
  def decrement_user_counter_cache
    user.decrement!(:journal_posts_count) if parent_type == 'User' && published?
    true
  end
  
  def to_s
    "<Post #{self.id}: #{self.to_plain_s}>"
  end
  
  def to_plain_s(options = {})
    s = self.title || ""
    s += ", by #{self.user.try(:login)}" unless options[:no_user]
    s
  end
  
  def draft?
    published_at.blank?
  end

  def published?
    !published_at.blank? && errors[:published_at].blank?
  end

  def editable_by?(u)
    return false unless u
    user_id == u.id
  end

  def mentioned_users
    return [ ] unless published? && body
    body.mentioned_users
  end

end
