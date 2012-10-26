class Comment < ActiveRecord::Base
  acts_as_flaggable
  belongs_to :parent, :polymorphic => true
  belongs_to :user
  
  validates_length_of :body, :within => 1..5000, :message => "can't be blank"
  
  # after_create :deliver_notification
  after_create :update_parent_counter_cache
  after_destroy :update_parent_counter_cache
  
  notifies_subscribers_of :parent, :notification => "activity", :include_owner => true
  auto_subscribes :user, :to => :parent
  
  scope :by, lambda {|user| where("comments.user_id = ?", user)}
  scope :since, lambda {|datetime| where("comments.created_at > DATE(?)", datetime)}
  
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
      parent.update_attribute(:comments_count, parent.comments.count)
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
end
