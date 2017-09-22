class Message < ActiveRecord::Base
  acts_as_spammable fields: [ :subject, :body ],
    user: :from_user

  blockable_by lambda { |message| message.to_user }
  
  belongs_to :user
  belongs_to :from_user, :class_name => "User"
  belongs_to :to_user, :class_name => "User"

  validates_presence_of :user, :from_user_id, :to_user_id
  validate :validate_to_not_from
  validates :body, :presence => true
  before_create :set_read_at, :set_subject_for_reply
  after_save :set_thread_id
  after_create :deliver_email
  
  scope :inbox, -> { where("user_id = to_user_id") } #.select("DISTINCT ON (thread_id) messages.*")
  scope :sent, -> { where("user_id = from_user_id") } #.select("DISTINCT ON (thread_id) messages.*")
  scope :unread, -> { where("read_at IS NULL") }

  INBOX = "inbox"
  SENT = "sent"
  BOXES = [INBOX, SENT]

  attr_accessor :html
  attr_accessor :skip_email

  def to_s
    "<Message #{id} user:#{user_id} from:#{from_user_id} to:#{to_user_id} subject:#{subject.to_s[0..10]}>"
  end

  def send_message
    reload
    new_message = dup
    new_message.user = to_user
    new_message.read_at = nil
    new_message.save!
  end

  def to_user_copy
    return self if to_user_id == user_id
    to_user.messages.inbox.where(:thread_id => thread_id).detect{|m| m.body == body}
  end

  def from_user_copy
    return self if from_user_id == user_id
    from_user.messages.sent.where(:thread_id => thread_id).detect{|m| m.body == body}
  end

  def set_read_at
    if user_id == from_user_id
      self.read_at = Time.now
    end
    true
  end

  def set_thread_id
    if thread_id.blank?
      Message.where(id: id).update_all(thread_id: id)
    end
    true
  end

  def set_subject_for_reply
    return true if thread_id.blank?
    first = Message.where(:thread_id => thread_id, :user_id => user_id).order("id asc").first
    if first && first != self
      self.subject = first.subject
      self.subject = "Re: #{subject}" unless subject.to_s =~ /^Re:/
    end
    true
  end

  def validate_to_not_from
    if to_user_id == from_user_id
      errors.add(:base, "You can't send a message to yourself")
    end
  end

  def deliver_email
    return true if user_id == from_user_id
    return true if skip_email
    Emailer.delay(:priority => USER_INTEGRITY_PRIORITY).new_message(id)
    true
  end

  def flagged_with(flag, options = {})
    evaluate_new_flag_for_spam(flag)
    Message.where(:user_id => to_user_id, :thread_id => thread_id).destroy_all
  end
end
