class Comment < ActiveRecord::Base
  belongs_to :parent, :polymorphic => true
  belongs_to :user
  
  validates_length_of :body, :within => 1..5000, :message => "can't be blank"
  
  # after_create :deliver_notification
  after_create :update_parent_counter_cache
  after_destroy :update_parent_counter_cache
  
  notifies_subscribers_of :parent, :notification => "activity", :include_owner => true
  auto_subscribes :user, :to => :parent
  
  named_scope :by, lambda {|user| 
    {:conditions => ["comments.user_id = ?", user]}}
  
  named_scope :since, lambda {|datetime|
    {:conditions => ["comments.created_at > DATE(?)", datetime]}}
  
  def formatted_body
    BlueCloth::new(self.body).to_html
  end
  
  def deliver_notification
    return true unless parent.respond_to?(:user_id) && parent.user_id != user_id && 
      parent.user && !parent.user.email.blank? && parent.user.prefers_comment_email_notification?
    Emailer.send_later(:deliver_comment_notification, self)
    true
  end
  
  def update_parent_counter_cache
    if parent && parent.class.column_names.include?("comments_count")
      parent.update_attribute(:comments_count, parent.comments.count)
    end
    true
  end
end
