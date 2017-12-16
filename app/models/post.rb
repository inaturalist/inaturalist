class Post < ActiveRecord::Base
  acts_as_spammable :fields => [ :title, :body ],
                    :comment_type => "blog-post"

  has_subscribers
  notifies_subscribers_of :parent, {
    :on => [:update, :create],
    :queue_if => lambda{ |post|
      conditions = { notifier_type: "Post", notifier_id: post.id }
      existing_updates_count = UpdateAction.where(conditions).count
      # destroy existing updates if user *unpublishes* a post
      if post.draft? && existing_updates_count > 0
        UpdateAction.delete_and_purge(conditions)
        return false
      end
      return !post.draft? && existing_updates_count == 0 && post.published_at_changed?
    },
    :if => lambda{|post, project, subscription|
      return true unless post.parent_type == 'Project'
      project_user = project.project_users.where(user_id: subscription.user_id).first
      project_user.prefers_updates?
    },
    :notification => "created_post",
    :include_notifier => true
  }
  notifies_users :mentioned_users,
    except: :previously_mentioned_users,
    on: :save,
    notification: "mention",
    if: lambda {|u| u.prefers_receive_mentions? }
  belongs_to :parent, :polymorphic => true
  belongs_to :user
  has_many :comments, :as => :parent, :dependent => :destroy
  has_and_belongs_to_many :observations, -> { uniq }
  
  validates_length_of :title, :in => 1..2000
  validates_presence_of :parent
  validate :user_must_be_on_site_long_enough
  
  before_save :skip_update_for_draft
  after_save :update_user_counter_cache
  after_destroy :update_user_counter_cache
  
  scope :published, -> { where("published_at IS NOT NULL") }
  scope :unpublished, -> { where("published_at IS NULL") }

  FORMATTING_SIMPLE = "simple"
  FORMATTING_NONE = "none"
  preference :formatting, :string, default: FORMATTING_SIMPLE

  ALLOWED_TAGS = %w(
    a abbr acronym b blockquote br cite code dl dt em embed h1 h2 h3 h4 h5 h6 hr i
    iframe img li object ol p param pre s small strike strong sub sup tt ul
    table tr td th
    audio source
    div
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
  
  def update_user_counter_cache
    if parent_type == "User" && published_at_changed?
      User.where( id: user_id, ).update_all( journal_posts_count: user.journal_posts.published.count )
    end
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

  def to_param
    "#{id}-#{title.parameterize}"
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

  def previously_mentioned_users
    return [ ] if !published? || body_was.blank?
    body.mentioned_users & body_was.to_s.mentioned_users
  end

end
