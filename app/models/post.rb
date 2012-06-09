class Post < ActiveRecord::Base
  has_subscribers
  belongs_to :parent, :polymorphic => true
  belongs_to :user
  has_many :comments, :as => :parent, :dependent => :destroy
  has_and_belongs_to_many :observations, :uniq => true
  
  validates_length_of :title, :in => 1..2000
  
  before_save :skip_update_for_draft
  after_create :increment_user_counter_cache
  after_destroy :decrement_user_counter_cache
  
  named_scope :published, :conditions => "published_at IS NOT NULL"
  named_scope :unpublished, :conditions => "published_at IS NULL"
  
  def skip_update_for_draft
    @skip_update = true if draft?
    true
  end
  
  # Update the counter cache in users.
  def increment_user_counter_cache
    self.user.increment!(:journal_posts_count)
    true
  end
  
  def decrement_user_counter_cache
    self.user.decrement!(:journal_posts_count)
    true
  end
  
  def to_s
    "<Post #{self.id}: #{self.to_plain_s}>"
  end
  
  def to_plain_s(options = {})
    s = self.title
    s += ", by #{self.user.login}" unless options[:no_user]
    s
  end
  
  def draft?
    published_at.blank?
  end
end
