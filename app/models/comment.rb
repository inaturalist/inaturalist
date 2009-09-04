class Comment < ActiveRecord::Base
  belongs_to :parent, :polymorphic => true
  belongs_to :user
  
  validates_length_of :body, :within => 1..5000, :message => "can't be blank"
  
  after_create :deliver_notification
  
  named_scope :by, lambda {|user| 
    {:conditions => ["comments.user_id = ?", user]}}
  
  named_scope :since, lambda {|datetime|
    {:conditions => ["comments.created_at > DATE(?)", datetime]}}
  
  def formatted_body
    BlueCloth::new(self.body).to_html
  end
  
  def deliver_notification
    if self.parent.user_id != self.user_id &&
        self.parent.user.preferences.comment_email_notification
      spawn(:nice => 7) do
        Emailer.deliver_comment_notification(self)
      end
    end
  end
end
