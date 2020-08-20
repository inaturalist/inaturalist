class Comment < ActiveRecord::Base

  acts_as_spammable fields: [ :body ],
                    comment_type: "comment"
  acts_as_votable
  has_moderator_actions
  SUBSCRIBABLE = false

  # Uncomment to require speech privilege to make comments on anything other
  # than your own content
  # requires_privilege :speech, if: Proc.new {|c|
  #   c.parent.respond_to?(:user) && c.parent.user.id != user.id
  # }

  belongs_to_with_uuid :parent, polymorphic: true
  belongs_to :user

  MAX_LENGTH = 5000
  validates_length_of :body, within: 1..MAX_LENGTH
  validates_presence_of :parent
  validate :parent_prefers_comments

  after_create :update_parent_counter_cache
  after_destroy :update_parent_counter_cache
  after_save :index_parent
  after_touch :index_parent
  after_destroy :index_parent

  notifies_subscribers_of :parent, notification: "activity", include_owner: true
  notifies_users :mentioned_users,
    on: :save,
    delay: false,
    notification: "mention",
    if: lambda {|u| u.prefers_receive_mentions? }
  auto_subscribes :user, to: :parent
  blockable_by lambda {|comment| comment.parent.try(:user_id) }

  scope :by, lambda {|user| where("comments.user_id = ?", user)}
  scope :for_observer, lambda {|user| 
    joins("JOIN observations o ON o.id = comments.parent_id").
    where("comments.parent_type = 'Observation'").
    where("o.user_id = ?", user)
  }
  scope :since, lambda {|datetime| where("comments.created_at > DATE(?)", datetime)}
  scope :dbsearch, lambda {|q| where("comments.body ILIKE ?", "%#{q}%")}

  include ActsAsUUIDable

  attr_accessor :html, :bulk_delete, :wait_for_obs_index_refresh

  def to_s
    "<Comment #{id} user_id: #{user_id} parent_type: #{parent_type} parent_id: #{parent_id}>"
  end

  def to_plain_s(options = {})
    "Comment #{id}"
  end

  def as_indexed_json
    return unless user
    {
      id: id,
      uuid: uuid,
      user: user.as_indexed_json(no_details: true),
      created_at: created_at,
      created_at_details: ElasticModel.date_details(created_at),
      body: body,
      flags: flags.map(&:as_indexed_json),
      moderator_actions: moderator_actions.map(&:as_indexed_json),
      hidden: hidden?
    }
  end

  def update_parent_counter_cache
    if parent && parent.class.column_names.include?("comments_count")
      if parent.class.column_names.include?("updated_at")
        parent.class.where(id: parent_id).update_all(comments_count: parent.comments.count, updated_at: Time.now)
      else
        parent.class.where(id: parent_id).update_all(comments_count: parent.comments.count)
      end
    end
    true
  end

  def deletable_by?(deleting_user)
    return false if deleting_user.blank?
    return true if deleting_user.id == user_id
    return true if deleting_user.id == parent.try_methods(:user_id)
    return true if deleting_user.is_curator? || deleting_user.is_admin?
    false
  end

  def mentioned_users
    return [ ] unless body
    body.mentioned_users
  end

  def index_parent
    return if @parent_indexed
    return if bulk_delete
    if parent && parent.respond_to?(:elastic_index!)
      if parent.is_a?( Observation )
        parent.wait_for_index_refresh = !!wait_for_obs_index_refresh
      end
      parent.elastic_index!
      @parent_indexed = true
    end
  end

  def flagged_with(flag, options)
    evaluate_new_flag_for_spam(flag)
    index_parent
  end

  def parent_prefers_comments
    if parent && parent.respond_to?( :prefers_no_comments? ) && parent.prefers_no_comments?
      errors.add( :parent, :prefers_no_comments )
    end
    true
  end

end
