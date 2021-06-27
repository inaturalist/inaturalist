class Post < ActiveRecord::Base
  acts_as_spammable :fields => [ :title, :body ],
                    :comment_type => "blog-post"
  # include ActsAsUUIDable
  before_validation :set_uuid
  def set_uuid
    self.uuid ||= SecureRandom.uuid
    self.uuid = uuid.downcase
    true
  end

  has_subscribers to: {
    comments: { notification: "activity", include_owner: true }
  }
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
      return !post.draft? && existing_updates_count == 0 && post.previous_changes[:published_at]
    },
    :if => lambda{|post, project, subscription|
      return true unless post.parent_type == 'Project'
      project_user = project.project_users.where(user_id: subscription.user_id).first
      # as it stands right now, collection/umbrella projects don't necessarily
      # create ProjectUsers, so only check preferences if one exists
      return true unless project_user
      project_user.prefers_updates?
    },
    :notification => "created_post",
    :include_notifier => true
  }
  notifies_users :mentioned_users,
    on: :save,
    delay: false,
    notification: "mention",
    if: lambda {|u| u.prefers_receive_mentions? }
  belongs_to :parent, :polymorphic => true
  belongs_to :user
  has_many :comments, :as => :parent, :dependent => :destroy
  has_and_belongs_to_many :observations, -> { uniq }

  validates_length_of :title, in: 1..2000
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

  preference :no_comments, :boolean, default: false

  ALLOWED_TAGS = %w(
    a
    abbr
    acronym
    audio
    b
    blockquote
    br
    cite
    code
    del
    div
    dl
    dt
    em
    embed
    h1
    h2
    h3
    h4
    h5
    h6
    hr
    i
    iframe
    img
    ins
    li
    object
    ol
    p
    param
    pre
    s
    small
    source
    strike
    strong
    sub
    sup
    table
    td
    tfoot
    th
    thead
    tr
    tt
    ul
  )

  ALLOWED_ATTRIBUTES = %w(
    abbr
    align
    alt
    cite
    class
    controls
    frameborder
    frameBorder
    height
    href
    name
    preload
    rel
    seamless
    src
    style
    target
    title
    value
    width
    xml:lang
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
    if parent_type == "User" && (published_at_changed? || destroyed?) 
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

  def editable_by?( u )
    return false unless u.is_a?( User )
    return true if user_id == u.id
    return true if parent.is_a?( Project ) && parent.curated_by?( u )
    return true if parent.is_a?( Site ) && parent.editable_by?( u )
    return true if parent.is_a?( User ) && parent == u
    user_id == u.id
  end

  def mentioned_users
    return [ ] unless published? && body
    body.mentioned_users
  end

end
