class Flag < ActiveRecord::Base
  # include ActsAsUUIDable
  before_validation :set_uuid
  def set_uuid
    self.uuid ||= SecureRandom.uuid
    self.uuid = uuid.downcase
    true
  end
  SPAM = "spam"
  INAPPROPRIATE = "inappropriate"
  COPYRIGHT_INFRINGEMENT = "copyright infringement"
  FLAGS = [
    SPAM,
    INAPPROPRIATE,
    COPYRIGHT_INFRINGEMENT
  ]
  belongs_to :flaggable, polymorphic: true
  belongs_to :flaggable_user, class_name: "User", foreign_key: "flaggable_user_id", inverse_of: :flags_as_flaggable_user

  has_subscribers :to => {
    :comments => {:notification => "activity", :include_owner => true},
  }
  notifies_subscribers_of :self, :notification => "activity", :include_owner => true,
    :on => :update,
    :queue_if => Proc.new {|flag|
      # existing flag whose comment has been changed
      !flag.previous_changes[:id] && flag.previous_changes[:comment]
    }
  auto_subscribes :resolver, :on => :update, :if => Proc.new {|record, resource|
    record.resolved_changed? && !record.resolver.blank? && 
      !record.resolver.subscriptions.where(:resource_type => "Flag", :resource_id => record.id).exists?
  }

  blockable_by lambda {|flag| flag.flaggable.try(:user_id) }, on: :create
  
  # NOTE: Flags belong to a user
  belongs_to :user, inverse_of: :flags
  belongs_to :resolver, :class_name => 'User', :foreign_key => 'resolver_id'
  has_many :comments, :as => :parent, :dependent => :destroy

  before_save :check_resolved
  before_create :set_flaggable_user_id
  before_create :set_flaggable_content

  after_create :notify_flaggable_on_create
  after_update :notify_flaggable_on_update
  after_destroy :notify_flaggable_on_destroy
  
  # A user can flag a specific flaggable with a specific flag once
  validates_length_of :flag, :in => 3..256, :allow_blank => false
  validates_length_of :comment, :maximum => 256, :allow_blank => true
  validates_uniqueness_of :user_id, scope: [
    :flaggable_id,
    :flaggable_type,
    :flag,
    # This only works if the validation is on create, i.e. no other user /
    # flaggable / flag combo can exist when resolved_at is null
    :resolved_at
  ], message: :already_flagged, on: :create
  validate :flaggable_type_valid

  def to_s
    "<Flag #{id} user_id: #{user_id} flaggable_type: #{flaggable_type} flaggable_id: #{flaggable_id}>"
  end
  
  def flaggable_type_valid
    if FlagsController::FLAG_MODELS.include?(flaggable_type)
      true
    else
      errors.add(:flaggable_type, "can't be flagged")
    end
  end

  def notify_flaggable_on_create
    if flaggable && flaggable.respond_to?(:flagged_with)
      flaggable.flagged_with(self, action: "created")
    end
    true
  end

  def notify_flaggable_on_update
    if flaggable && flaggable.respond_to?(:flagged_with) && resolved_changed?
      if resolved?
        flaggable.flagged_with(self, action: "resolved")
      else
        flaggable.flagged_with(self, action: "unresolved")
      end
    end
    true
  end

  def notify_flaggable_on_destroy
    if flaggable && flaggable.respond_to?(:flagged_with)
      flaggable.flagged_with(self, action: "destroyed")
    end
    true
  end

  def is_akismet_spam_flag?
    user_id == 0 && flag == Flag::SPAM
  end

  def as_indexed_json
    {
      id: id,
      flag: flag,
      comment: comment,
      user_id: user_id,
      resolver_id: resolver_id,
      resolved: resolved,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  # Helper class method to lookup all flags assigned
  # to all flaggable types for a given user.
  def self.find_flags_by_user(user)
    find(:all,
      :conditions => ["user_id = ?", user.id],
      :order => "created_at DESC"
    )
  end
  
  # Helper class method to look up all flags for 
  # flaggable class name and flaggable id.
  def self.find_flags_for_flaggable(flaggable_str, flaggable_id)
    find(:all,
      :conditions => ["flaggable_type = ? and flaggable_id = ?", flaggable_str, flaggable_id],
      :order => "created_at DESC"
    )
  end

  # Helper class method to look up a flaggable object
  # given the flaggable class name and id 
  def self.find_flaggable(flaggable_str, flaggable_id)
    flaggable_str.constantize.find(flaggable_id)
  end
  
  def flagged_object
    if klass = Object.const_get( flaggable_type )
      klass.find_by_id( flaggable_id )
    end
  end

  def check_resolved
    if resolved_changed? && resolved
      self.resolved_at = Time.now
    elsif resolved_changed?
      self.resolved_at = nil
      self.resolver = nil
      self.comment = nil
    end
    true
  end

  def get_flaggable_user
    case flaggable_type
    when "User" then flaggable
    when "Message" then flaggable.from_user
    else
      k, reflection = flaggable.class.reflections.detect{|r| r[1].class_name == "User" && r[1].macro == :belongs_to }
      if reflection
        flaggable.send( k )
      else
        nil
      end
    end
  end

  def set_flaggable_user_id
    return true unless flaggable
    if u = get_flaggable_user
      self.flaggable_user_id = u.id
    end
    true
  end

  def set_flaggable_content
    return true unless flaggable
    self.flaggable_content = flaggable.try_methods(:body, :description)
    true
  end

  def flaggable_content_viewable_by?( user )
    if flaggable_type == "Message"
      return false unless user && user.is_admin?
    end
    !flaggable_content.blank? && user && user.is_curator?
  end

  def deletable_by?( user )
    return false if new_record? || user.blank?
    return true if user.is_admin?
    return true if user.id === self.user_id && !resolved? && !comments.any?
    false
  end

end
