# frozen_string_literal: true

class Post < ApplicationRecord
  acts_as_spammable fields: [:title, :body],
    comment_type: "blog-post"
  include ActsAsUUIDable
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
    on: [:update, :create],
    unless: lambda {| post |
      post.draft? || !post.saved_change_to_published_at?
    },
    if: lambda {| post, project, subscription |
      return true unless post.parent_type == "Project"

      project_user = project.project_users.where( user_id: subscription.user_id ).first
      # as it stands right now, collection/umbrella projects don't necessarily
      # create ProjectUsers, so only check preferences if one exists
      return true unless project_user

      project_user.prefers_updates?
    },
    notification: "created_post",
    include_notifier: true
  }
  notifies_users :mentioned_users,
    on: :save,
    delay: false,
    notification: "mention",
    if: ->( u ) { u.prefers_receive_mentions? }
  belongs_to :parent, polymorphic: true
  belongs_to :user
  has_many :comments, as: :parent, dependent: :destroy
  has_and_belongs_to_many :observations, -> { distinct }

  validates_length_of :title, in: 1..2000
  validates_length_of :body, in: 1..1_000_000
  validates_presence_of :parent
  validate :user_must_be_on_site_long_enough

  before_save :skip_update_for_draft
  after_save :update_user_counter_cache
  after_save :destroy_updates_if_unpublished
  after_destroy :update_user_counter_cache

  scope :published, -> { where( "published_at IS NOT NULL" ) }
  scope :unpublished, -> { where( "published_at IS NULL" ) }
  scope :dbsearch, lambda {| parent, q |
    where( parent: parent ).where( "posts.title ILIKE ? OR posts.body ILIKE ?", "%#{q}%", "%#{q}%" )
  }

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
    ul
  ).freeze

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
  ).freeze

  def user_must_be_on_site_long_enough
    return unless !is_a?( Trip ) && published? && user.created_at > 24.hours.ago

    errors.add( :user, :must_be_on_site_long_enough )
  end

  def skip_update_for_draft
    @skip_update = true if draft?
    true
  end

  def update_user_counter_cache
    if parent_type == "User" && ( saved_change_to_published_at? || destroyed? )
      User.where( id: user_id ).update_all( journal_posts_count: user.journal_posts.published.count )
    end
    true
  end

  def destroy_updates_if_unpublished
    return if published?

    UpdateAction.delete_and_purge( { notifier_type: "Post", notifier_id: id } )
  end

  def to_s
    "<Post #{id}: #{to_plain_s}>"
  end

  def to_plain_s( options = {} )
    s = title || ""
    s += ", by #{user.try( :login )}" unless options[:no_user]
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

  def editable_by?( user )
    return false unless user.is_a?( User )
    return true if user_id == user.id
    return true if parent.journal_owned_by? user

    user_id == user.id
  end

  def mentioned_users
    return [] unless published? && body

    body.mentioned_users
  end
end
