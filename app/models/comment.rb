class Comment < ActiveRecord::Base
  acts_as_spammable :fields => [ :body ]

  belongs_to :parent, :polymorphic => true
  belongs_to :user
  
  validates_length_of :body, :within => 1..5000, :message => "can't be blank"
  validates_presence_of :parent
  
  after_create :update_parent_counter_cache
  after_destroy :update_parent_counter_cache
  
  notifies_subscribers_of :parent, :notification => "activity", :include_owner => true
  notifies_users :mentioned_users, notification: "mention"
  auto_subscribes :user, :to => :parent
  
  scope :by, lambda {|user| where("comments.user_id = ?", user)}
  scope :for_observer, lambda {|user| 
    joins("JOIN observations o ON o.id = comments.parent_id").
    where("comments.parent_type = 'Observation'").
    where("o.user_id = ?", user)
  }
  scope :since, lambda {|datetime| where("comments.created_at > DATE(?)", datetime)}
  scope :dbsearch, lambda {|q| where("comments.body ILIKE ?", "%#{q}%")}
  
  attr_accessor :html

  def to_s
    "<Comment #{id} user_id: #{user_id} parent_type: #{parent_type} parent_id: #{parent_id}>"
  end

  def to_plain_s(options = {})
    "Comment #{id}"
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
    return [ ] unless parent_type == "Observation"
    body.mentioned_users
  end

end
