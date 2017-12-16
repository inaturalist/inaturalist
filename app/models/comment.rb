class Comment < ActiveRecord::Base

  acts_as_spammable fields: [ :body ],
                    comment_type: "comment"
  acts_as_votable
  SUBSCRIBABLE = false

  belongs_to :parent, polymorphic: true
  belongs_to :user

  validates_length_of :body, within: 1..5000
  validates_presence_of :parent

  after_create :update_parent_counter_cache
  after_destroy :update_parent_counter_cache
  after_save :index_parent
  after_destroy :index_parent

  notifies_subscribers_of :parent, notification: "activity", include_owner: true
  notifies_users :mentioned_users,
    except: :previously_mentioned_users,
    on: :save,
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

  attr_accessor :html

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
      flags: flags.map(&:as_indexed_json)
    }
  end

  def formatted_body
    BlueCloth::new(self.body).to_html
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

  def new_mentioned_users
    return [ ] unless body && body_changed?
    body.mentioned_users - body_was.to_s.mentioned_users
  end

  def previously_mentioned_users
    return [ ] unless body_was.blank?
    body.mentioned_users & body_was.to_s.mentioned_users
  end

  def index_parent
    if parent && parent.respond_to?(:elastic_index!)
      parent.elastic_index!
    end
  end

  def flagged_with(flag, options)
    evaluate_new_flag_for_spam(flag)
    index_parent
  end

end
