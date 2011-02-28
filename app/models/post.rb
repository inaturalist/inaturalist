class Post < ActiveRecord::Base
  acts_as_activity_streamable
  belongs_to :parent, :polymorphic => true
  belongs_to :user
  has_many :comments, :as => :parent, :dependent => :destroy
  has_and_belongs_to_many :observations, :uniq => true
  
  validates_length_of :title, :in => 1..2000
  
  after_create :increment_user_counter_cache
  after_destroy :decrement_user_counter_cache
  
  named_scope :published, :conditions => "published_at > 0"
  named_scope :unpublished, :conditions => "published_at IS NULL"
  
  # Update the counter cache in users.
  def increment_user_counter_cache
    self.user.increment!(:journal_posts_count)
  end
  
  def decrement_user_counter_cache
    self.user.decrement!(:journal_posts_count)
  end
  
  def to_s
    "<Post #{self.id}: #{self.to_plain_s}>"
  end
  
  def to_plain_s(options = {})
    s = self.title
    s += ", by #{self.user.login}" unless options[:no_user]
    s
  end
end
